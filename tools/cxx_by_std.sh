#!/bin/sh
# Copyright (C) 2026 OXT-Beyond contributors.
#
# This file is part of OXT-Beyond.
#
# OXT-Beyond is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License v3 as published by the Free
# Software Foundation.
#
# OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.

# The C++ compiler for a Linux build whose usual compiler has no C++20.
#
#   CXX=tools/cxx_by_std.sh LINK=tools/cxx_by_std.sh make config-linux-x86_64
#
# CEF 156's headers need C++20 (<concepts>), which the GCC 9 of the build's
# Ubuntu 20.04 container does not have. Only the browser's sources take
# -std=c++20 (libbrowser, revbrowser and the CEF wrapper, on x86_64 Linux):
# those compile with $OXT_CXX20 (default g++-10), and everything else, and
# every link, with $OXT_CXX (default c++), as before. GCC 10 on Ubuntu 20.04
# uses the system's libstdc++ (GCC 10's, GLIBCXX_3.4.28), which the GCC 9
# build already needs: the binaries need nothing newer.
#
# Without it, a compiler that has C++20 (GCC 10 or newer) builds it all.

for arg in "$@"; do
	case $arg in
		-std=c++20|-std=gnu++20|-std=c++2a|-std=gnu++2a)
			exec ${OXT_CXX20:-g++-10} "$@"
			;;
	esac
done
exec ${OXT_CXX:-c++} "$@"
