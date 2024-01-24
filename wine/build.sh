#!/usr/bin/env bash

# buildertools - Script for build lastest wine-git
# Copyright (C) 2023  IroAlexis <iroalexis@outlook.fr>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Based on TkG's work https://github.com/Frogging-Family/wine-tkg-git


if [ -n "$DEBUG" ]
then
	set -xe
else
	set -e
fi

[ -z "$XDG_USER_DATA" ] && XDG_USER_DATA="$HOME/.local/share"

LN_BASEDIR="$(realpath "$(dirname "$0")")"
LN_BUILDDIR="/tmp/buildertools"
LN_USER_DATA="$XDG_USER_DATA/buildertools"



_error()
{
	echo -e "\033[1;31m==> ERROR: $1\033[1;0m" >&2
}

_msg()
{
	echo -e "\033[1;34m->\033[1;0m \033[1;1m$1\033[1;0m" >&2
}

_warning()
{
	echo -e "\033[1;33m==> WARNING: $1\033[1;0m" >&2
}

_run_patcher()
{
	if ! patch -d "${_src_path}" -Np1 < "$1"
	then
		_error "$(basename "$1")"
		exit 1
	fi
}


apply_patches()
{
	for _patch in "$LN_BASEDIR"/patches/*.patch
	do
		_msg "################################"
		_msg "Applying $(basename "${_patch}")"
		_msg "################################"

		_run_patcher "${_patch}"
	done
}

apply_userpatches()
{
	for _patch in "$LN_BASEDIR"/userpatches/*.patch
	do
		if [ -e "${_patch}" ]
		then
			local _name
			local _rslt
			_name="$(basename -s .patch "${_patch}")"

			if [[ ${_name} =~ ^[0-9]+$ ]]
			then
				_msg "https://gitlab.winehq.org/wine/wine/-/merge_requests/${_name}"
			else
				_msg "${_name}.patch"
			fi

			read -rp "Do you want apply this patch? [N/y] " _rslt
			if [[ ${_rslt} =~ [Yy] ]]
			then
				_run_patcher "${_patch}"
			fi
		fi
	done
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
		_warning "ccache not installed"
	fi
}

polish_source()
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

_msg "Cloning/fetching gitlab/wine and prepare source... Please be patient."
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


_msg "Cleaning wine source code tree..."
${_git_src} reset --hard HEAD
${_git_src} clean -xdf


apply_patches
apply_userpatches
(cd "${_src_path}" && polish_source)


_msg "Configuring Wine build directory..."
BUILD_DIR="/tmp/build64"
mkdir -p "$BUILD_DIR"

export_ccache
(cd "$BUILD_DIR" && "${_src_path}"/configure \
	--prefix="${_prefix}" \
	--enable-win64 \
	--enable-archs=i386,x86_64 \
	--disable-tests \
	--with-gstreamer)


_msg "Building..."
make -C "$BUILD_DIR" -j"$(nproc)"


_msg "Installing to ${_prefix}..."
if [ -d "${_prefix}" ]
then
	mv "${_prefix}" "${_prefix}.old"
fi

if make -C "$BUILD_DIR" install
then
	# Workaround for winetricks and cie
	(cd "${_prefix}/bin" && ln -s wine wine64)

	_msg "Wine build available here: ${_prefix}"
fi


exit 0
