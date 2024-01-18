#!/usr/bin/env bash

# Based on TkG's work https://github.com/Frogging-Family/wine-tkg-git

set -e

[ -z "$XDG_USER_DATA" ] && XDG_USER_DATA="$HOME/.local/share"

LN_BASEDIR="$(realpath "$(dirname "$0")")"
LN_BUILDDIR="/tmp/ln-tools"
LN_USER_DATA="$XDG_USER_DATA/ln-tools"


msg()
{
	echo -e "\033[1;34m->\033[1;0m \033[1;1m$1\033[1;0m" >&2
}

error()
{
	echo -e "\033[1;31m==> ERROR: $1\033[1;0m" >&2
}

warning()
{
	echo -e "\033[1;33m==> WARNING: $1\033[1;0m" >&2
}

export_ccache()
{
	if command -v ccache &>/dev/null
	then
		CC="ccache gcc"
		export CC
		CXX="ccache g++"
		export CXX
		CROSSCC="ccache x86_64-w64-mingw32-gcc"
		export CROSSCC
		x86_64_CC="$CROSSCC"
		export x86_64_CC

		# Required for new-style WoW64 builds (otherwise 32-bit portions won't be ccached)
		i386_CC="ccache i686-w64-mingw32-gcc"
		export i386_CC
	else
		warning "ccache not installed"
	fi
}

patcher()
{
	if ! patch -d "${_src_path}" -Np1 < "$1"
	then
		error "$(basename "$1")"
		exit 1
	fi
}

ln_patches()
{
	for _patch in "$LN_BASEDIR"/patches/wine/*.patch
	do
		msg "Applying $(basename "${_patch}")"

		patcher "${_patch}"
	done
}

user_patches()
{
	for _patch in "$LN_BASEDIR"/userpatches/wine/*.patch
	do
		local _name
		local _rslt
		_name="$(basename -s .patch "${_patch}")"

		if [[ ${_name} =~ ^[0-9]+$ ]]
		then
			msg "https://gitlab.winehq.org/wine/wine/-/merge_requests/${_name}"
		else
			msg "${_name}.patch"
		fi

		read -rp "Do you want apply this patch? [N/y] " _rslt
		if [[ ${_rslt} =~ [Yy] ]]
		then
			patcher "${_patch}"
		fi
	done
}

polish()
{
	git add ./* && true
	
	./tools/make_makefiles
	./dlls/winevulkan/make_vulkan
	./tools/make_requests
	
	if [ -e tools/make_specfiles ]; then
	  ./tools/make_specfiles
	fi
	autoreconf -fiv
}


_repo_url_mainline="https://gitlab.winehq.org/wine/wine.git"
_mirror_path="$LN_USER_DATA/wine"
_src_path="$LN_BUILDDIR/wine"
_git_mir="git -C ${_mirror_path}"
_git_src="git -C ${_src_path}"

_pkgname="ln-wine-git"
_prefix="$HOME/tools/${_pkgname}"

msg "Cloning/fetching gitlab/wine and prepare source... Please be patient."
if ! [ -d "${_mirror_path}" ]
then
	git clone --mirror "${_repo_url_mainline}" "${_mirror_path}"
fi
${_git_mir} fetch --all -p

if [ -d "${_src_path}" ]
then
	rm -rf "${_src_path}"
fi
git clone "${_mirror_path}" "${_src_path}"


msg "Cleaning wine source code tree..."
${_git_src} reset --hard HEAD
${_git_src} clean -xdf


ln_patches
user_patches
(cd "${_src_path}" && polish)


msg "Configuring Wine build directory..."
BUILD_DIR="/tmp/build64"
mkdir -p "$BUILD_DIR"

export_ccache
(cd "$BUILD_DIR" && "${_src_path}"/configure \
	--prefix="${_prefix}" \
	--enable-win64 \
	--enable-archs=i386,x86_64 \
	--disable-tests)


msg "Building..."
make -C "$BUILD_DIR" -j"$(nproc)"


msg "Installing to ${_prefix}..."
if [ -d "${_prefix}" ]
then
	mv "${_prefix}" "${_prefix}.old"
fi

if make -C "$BUILD_DIR" install
then
	msg "Wine build available here: ${_prefix}"
fi

# Fix for winetricks
(cd "${_prefix}/bin" && ln -s wine wine64)


exit 0
