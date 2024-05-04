#!/usr/bin/env bash

# buildtools - Script for build lastest wine-git
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

_name="buildtools"

if [ -n "$DEBUG" ]
then
	set -xe
else
	set -e
fi

[ -z "$XDG_USER_DATA" ] && XDG_USER_DATA="$HOME/.local/share"

pkgname="wine-fsync-git"
url="https://gitlab.winehq.org/wine/wine.git"

buildir="/tmp/${_name}"
userdata="$XDG_USER_DATA/${_name}"
destdir="$HOME/tools/${pkgname}"




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
	for _patch in "${_basedir}/patches/"*.patch
	do
		_msg "################################"
		_msg "Applying $(basename "${_patch}")"
		_msg "################################"

		_run_patcher "${_patch}"
	done
}

apply_userpatches()
{
	for _patch in "${_basedir}"/userpatches/*.patch
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

launch_build()
{
	"${_src_path}"/configure \
		--prefix="${destdir}" \
		--enable-win64 \
		--enable-archs=i386,x86_64 \
		--disable-tests \
		--with-gstreamer

	make -j"$(nproc)"
}

configure_ccache()
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


_basedir="$(realpath "$(dirname "$0")")"
_mirror_path="${userdata}/${url##*/}"
_src_path="${buildir}/${url##*/}"

_msg "Cloning/fetching gitlab/wine and prepare source... Please be patient."
if ! [ -d "${_mirror_path}" ]
then
	git clone --mirror "${url}" "${_mirror_path}"
fi
git -C "${_mirror_path}" fetch --all -p

if [ -d "${_src_path}" ]
then
	rm -rf "${_src_path}"
fi
git clone "${_mirror_path}" "${_src_path}"


_msg "Cleaning wine source code tree..."
git -C "${_src_path}" reset --hard HEAD
git -C "${_src_path}" clean -xdf


apply_patches
apply_userpatches
(cd "${_src_path}" && polish_source)


_wine_build="$buildir/${url##*/}-build"
mkdir -p "${_wine_build}"
configure_ccache

_msg "Building..."
(cd "${_wine_build}" && launch_build)

_msg "Installing to ${destdir}..."
if make -C "${_wine_build}" install
then
	# Workaround for winetricks and cie
	ln -sr "${destdir}/bin/wine" "${destdir}/bin/wine64"

	_msg "Wine build available here: ${destdir}"
fi


exit 0
