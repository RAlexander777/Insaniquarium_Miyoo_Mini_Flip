# Cross-compile to Linux armv7 hard-float against the Miyoo Mini's own sysroot.
#
# Two toolchains are mixed on purpose:
#   - Debian bookworm's arm-linux-gnueabihf gcc 12  -> the C++20 compiler
#   - the Miyoo buildroot sysroot (glibc 2.28)      -> the target headers/libs
#
# The device reports glibc 2.28 and the project needs C++20, and no released
# toolchain pairs those two: everything with a modern gcc targets glibc >= 2.31.
# Mixing them is what insaniquarium-port already does for aarch64 (bullseye
# sysroot + host gcc); here the sysroot is the Miyoo's.
#
# Validated: a C++20 test binary built this way needs at most GLIBC_2.25, well
# under the device's 2.28, and keeps __libc_csu_init so static constructors run.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

if(NOT WINFISH_SYSROOT)
	set(WINFISH_SYSROOT "/opt/miyoomini-toolchain/arm-linux-gnueabihf/libc")
endif()

# CMake re-includes this file inside every try_compile, where the project cache
# does not exist yet, and WINFISH_SYSROOT would otherwise arrive empty exactly
# while CMake is testing the compiler.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES WINFISH_SYSROOT)

if(NOT EXISTS "${WINFISH_SYSROOT}/usr/include")
	message(FATAL_ERROR "'${WINFISH_SYSROOT}' is not a sysroot: no usr/include")
endif()

set(CMAKE_C_COMPILER   arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_SYSROOT "${WINFISH_SYSROOT}")

# ------------------------------------------------------------------- headers
#
# --sysroot alone does not get the libc headers from the sysroot: the distro's
# cross gcc puts /usr/arm-linux-gnueabihf/include ahead of it, which is its own
# (much newer) glibc. That mismatch does not fail loudly -- it emits calls to
# symbols the target does not have, e.g. __isoc23_strtoul from glibc 2.38.
#
# GCC has no flag to drop a single directory, so -nostdinc turns them all off
# and the correct ones go back: the C++ and compiler-internal ones (its own, and
# fine) plus the sysroot's. The list is queried from the compiler so no gcc
# version is hardcoded in a path.
function(winfish_include_dirs lang out_var)
	execute_process(
		COMMAND ${CMAKE_CXX_COMPILER} --sysroot=${WINFISH_SYSROOT} -x ${lang} -E -v /dev/null
		ERROR_VARIABLE raw OUTPUT_QUIET ERROR_STRIP_TRAILING_WHITESPACE)
	string(REGEX MATCH "#include <\\.\\.\\.> search starts here:(.*)End of search list\\."
	       _ "${raw}")
	string(REPLACE "\n" ";" lines "${CMAKE_MATCH_1}")
	set(keep "")
	foreach(line IN LISTS lines)
		string(STRIP "${line}" dir)
		if(NOT dir OR NOT IS_DIRECTORY "${dir}")
			continue()
		endif()
		# Normalise before classifying: GCC lists the toolchain's glibc as
		#   /usr/lib/gcc-cross/arm-linux-gnueabihf/12/../../../../arm-linux-gnueabihf/include
		# which resolves to /usr/arm-linux-gnueabihf/include but, as text,
		# contains "/lib/gcc-cross/". Matching the unresolved path would keep
		# exactly the directory this is meant to drop.
		get_filename_component(dir "${dir}" REALPATH)

		if(dir MATCHES "/c\\+\\+/" OR dir MATCHES "/lib/gcc-cross/" OR dir MATCHES "/lib/gcc/")
			list(APPEND keep "-isystem" "${dir}")
		endif()
	endforeach()
	# The buildroot sysroot keeps its headers in one place, with no per-triplet
	# subdirectory, but add it if a future toolchain has one.
	list(APPEND keep "-isystem" "${WINFISH_SYSROOT}/usr/include")
	if(IS_DIRECTORY "${WINFISH_SYSROOT}/usr/include/arm-linux-gnueabihf")
		list(APPEND keep "-isystem" "${WINFISH_SYSROOT}/usr/include/arm-linux-gnueabihf")
	endif()
	list(JOIN keep " " joined)
	set(${out_var} "-nostdinc ${joined}" PARENT_SCOPE)
endfunction()

winfish_include_dirs(c++ WINFISH_CXX_INCLUDES)
winfish_include_dirs(c   WINFISH_C_INCLUDES)
set(CMAKE_CXX_FLAGS_INIT "-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard ${WINFISH_CXX_INCLUDES}")
set(CMAKE_C_FLAGS_INIT   "-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard ${WINFISH_C_INCLUDES}")

# ------------------------------------------------------------------- lookups
#
# Headers and libraries from the sysroot only, programs from the host only.
#
# NEVER for PROGRAM is required: the sysroot contains an ARM pkg-config binary,
# and if CMake finds it first it tries to run it on x86_64 and fails with
# 'Syntax error: "(" unexpected' -- the shell trying to interpret an ELF.
set(CMAKE_FIND_ROOT_PATH "${WINFISH_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ------------------------------------------------------------------- linking
#
# --sysroot does not cover glibc for this cross gcc: the driver carries its own
# copy in /usr/arm-linux-gnueabihf/lib, an absolute host path outside the
# sysroot. Without these -L flags the "glibc 2.28" target is silently lost and
# the binary links against the build machine's glibc instead. -L is searched
# before the compiler's own directories, so listing the sysroot first is enough.
# The compiler's own library directory has to come first. -L is searched before
# the compiler's built-in directories, and the sysroot carries the device's
# *shared* libstdc++ (gcc 8.3). With the sysroot listed first, -lstdc++ resolves
# to that one and -static-libstdc++ loses, which surfaces as undefined C++20
# symbols the old library never exported:
#   std::__throw_bad_array_new_length, std::filesystem::__cxx11::path::_List
execute_process(COMMAND ${CMAKE_CXX_COMPILER} -print-libgcc-file-name
                OUTPUT_VARIABLE _winfish_libgcc OUTPUT_STRIP_TRAILING_WHITESPACE)
get_filename_component(WINFISH_GCC_LIBDIR "${_winfish_libgcc}" DIRECTORY)

set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-L${WINFISH_GCC_LIBDIR} -L${WINFISH_SYSROOT}/usr/lib -L${WINFISH_SYSROOT}/lib")

# -B matters even more than -L. The startup files (Scrt1.o, crti.o, crtn.o) are
# not found through -L, and the gcc driver's own list wins unless -B prepends.
# Since glibc 2.34 Scrt1.o passes NULL to __libc_start_main instead of
# __libc_csu_init, because from that release the loader walks .init_array
# itself; the Miyoo's 2.28 loader does not. With a new Scrt1.o the program
# starts and reaches main but no static constructor runs, silently. PopLib's
# registries and Res.cpp's resource tables are built that way.
#
# Verify on the finished binary:
#   arm-linux-gnueabihf-nm Insaniquarium | grep __libc_csu_init
string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -B${WINFISH_SYSROOT}/usr/lib/")

# When the linker takes a shared library from the sysroot it must be able to
# open that library's own DT_NEEDED entries to know which symbols are resolved.
string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT
       " -Wl,-rpath-link,${WINFISH_SYSROOT}/lib:${WINFISH_SYSROOT}/usr/lib")

set(CMAKE_SHARED_LINKER_FLAGS_INIT "${CMAKE_EXE_LINKER_FLAGS_INIT}")

set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${WINFISH_SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR}
	"${WINFISH_SYSROOT}/usr/lib/pkgconfig:${WINFISH_SYSROOT}/usr/share/pkgconfig")

# Onion keeps a port's private libraries next to the binary; the Onion launcher
# sets LD_LIBRARY_PATH explicitly, so $ORIGIN is enough here.
set(CMAKE_INSTALL_RPATH "$ORIGIN")
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
