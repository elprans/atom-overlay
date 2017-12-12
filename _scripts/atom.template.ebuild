# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# NOTE: this ebuild has been generated by atom-ebuild-gen.py from the
#       atom overlay.  If you would like to make changes, please consider
#       modifying the ebuild template and submitting a PR to
#       https://github.com/elprans/atom-overlay.

EAPI=6

PYTHON_COMPAT=( python2_7 )
inherit python-single-r1 multiprocessing rpm virtualx xdg-utils

DESCRIPTION="A hackable text editor for the 21st Century"
HOMEPAGE="https://atom.io"
MY_PV="${PV//_/-}"

ELECTRON_V=@@{ELECTRON_V}
ELECTRON_SLOT=@@{ELECTRON_S}

ASAR_V=0.13.0
# All binary packages depend on this
NAN_V=2.6.2

@@{BINMOD_VERSIONS}

# The x86_64 arch below is irrelevant, as we will rebuild all binary packages.
SRC_URI="
	https://github.com/${PN}/${PN}/releases/download/v${MY_PV}/atom.x86_64.rpm -> atom-bin-${MY_PV}.rpm
	https://github.com/${PN}/${PN}/archive/v${MY_PV}.tar.gz -> atom-${MY_PV}.tar.gz
	https://github.com/elprans/asar/releases/download/v${ASAR_V}-gentoo/asar-build.tar.gz -> asar-${ASAR_V}.tar.gz
	https://github.com/nodejs/nan/archive/v${NAN_V}.tar.gz -> nodejs-nan-${NAN_V}.tar.gz
@@{SRC_URI}
"

BINMODS=(
@@{BINMODS}
)

LICENSE="MIT"
SLOT="@@{SLOT}"
KEYWORDS="@@{KEYWORDS}"
IUSE=""
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

DEPEND="
	${PYTHON_DEPS}
	>=app-text/hunspell-1.3.3:=
	>=dev-libs/libgit2-0.23:=[ssh]
	>=dev-libs/libpcre2-10.22:=[jit,pcre16]
	>=gnome-base/libgnome-keyring-3.12:=
	>=dev-libs/oniguruma-6.6.0:=
	>=dev-util/ctags-5.8
	>=dev-util/electron-${ELECTRON_V}:${ELECTRON_SLOT}
	x11-libs/libxkbfile"
RDEPEND="
	${DEPEND}
	!sys-apps/apmd
"

S="${WORKDIR}/${PN}-${MY_PV}"
BIN_S="${WORKDIR}/${PN}-bin-${MY_PV}"
BUILD_DIR="${S}/out"

pkg_setup() {
	python-single-r1_pkg_setup
}

src_unpack() {
	local a

	for a in ${A} ; do
		case ${a} in
		*.rpm) srcrpm_unpack "${a}" ;;
		*) _unpack "${a}" ;;
		esac
	done

	mkdir "${BIN_S}" || die
	mv "${WORKDIR}/usr" "${BIN_S}" || die
}

src_prepare() {
	local install_dir="$(get_install_dir)"
	local suffix="$(get_install_suffix)"
	local nan_s="${WORKDIR}/nodejs-nan-${NAN_V}"
	local patch
	local binmod
	local _s

	mkdir "${BUILD_DIR}" || die
	cp -a "${BIN_S}/$(get_atom_rpmdir)/resources/app" \
		"${BUILD_DIR}/app" || die

	# Add source files omitted from the upstream binary distribution,
	# and which we want to include in ours.
	cp -a -t "${BUILD_DIR}/app" "${S}/spec" || die

	# Unpack app.asar
	if [ -e "${BIN_S}/$(get_atom_rpmdir)/resources/app.asar" ]; then
		easar extract "${BIN_S}/$(get_atom_rpmdir)/resources/app.asar" \
			"${BUILD_DIR}/app"
	fi

	cd "${BUILD_DIR}/app" || die

	eapply "${FILESDIR}/atom-python.patch"
	eapply "${FILESDIR}/apm-python.patch"
	eapply "${FILESDIR}/atom-unbundle-electron-r1.patch"
	eapply "${FILESDIR}/atom-apm-path-r2.patch"
	eapply "${FILESDIR}/atom-license-path-r1.patch"
	eapply "${FILESDIR}/atom-fix-app-restart-r1.patch"
	eapply "${FILESDIR}/atom-marker-layer-r1.patch"

	sed -i -e "s|{{NPM_CONFIG_NODEDIR}}|$(get_electron_nodedir)|g" \
		./atom.sh \
		|| die

	sed -i -e "s|{{ATOM_PATH}}|$(get_electron_dir)/electron|g" \
		./atom.sh \
		|| die

	sed -i -e "s|{{ATOM_RESOURCE_PATH}}|${EROOT%/}${install_dir}/app.asar|g" \
		./atom.sh \
		|| die

	sed -i -e "s|{{ATOM_PREFIX}}|${EROOT%/}|g" \
		./atom.sh \
		|| die

	sed -i -e "s|^#!/bin/bash|#!${EROOT%/}/bin/bash|g" \
		./atom.sh \
		|| die

	local env="export NPM_CONFIG_NODEDIR=$(get_electron_nodedir)\n\
			   export ELECTRON_NO_ASAR=1"
	sed -i -e \
		"s|\"\$binDir/\$nodeBin\"|${env}\nexec $(get_electron_dir)/node|g" \
			apm/bin/apm || die

	sed -i -e \
		"s|^\([[:space:]]*\)node[[:space:]]\+|\1\"$(get_electron_dir)/node\" |g" \
			apm/node_modules/npm/bin/node-gyp-bin/node-gyp || die

	sed -i -e \
		"s|atomCommand = 'atom';|atomCommand = '${EROOT%/}/usr/bin/atom${suffix}'|g" \
			apm/lib/test.js || die

	rm apm/bin/node || die

	sed -i -e "s|/$(get_atom_rpmdir)/atom|${EROOT%/}/usr/bin/atom${suffix}|g" \
		"${BIN_S}/usr/share/applications/$(get_atom_appname).desktop" || die

	for binmod in ${BINMODS[@]}; do
		_s="${WORKDIR}/$(package_dir ${binmod})"
		cd "${_s}" || die
		if _have_patches_for "${binmod}"; then
			for patch in "${FILESDIR}"/${binmod}-*.patch; do
				eapply "${patch}"
			done
		fi
	done

	cd "${BUILD_DIR}/app" || die

	# Unbundle bundled libs from modules

	_s="${WORKDIR}/$(package_dir git-utils)"
	${EPYTHON} "${FILESDIR}/gyp-unbundle.py" \
		--inplace --unbundle "git;libgit2;git2" \
		"${_s}/binding.gyp" || die

	_s="${WORKDIR}/$(package_dir oniguruma)"
	${EPYTHON} "${FILESDIR}/gyp-unbundle.py" \
		--inplace --unbundle "onig_scanner;oniguruma;onig" \
		"${_s}/binding.gyp" || die

	_s="${WORKDIR}/$(package_dir spellchecker)"
	${EPYTHON} "${FILESDIR}/gyp-unbundle.py" \
		--inplace --unbundle "spellchecker;hunspell;hunspell" \
		"${_s}/binding.gyp" || die

	_s="${WORKDIR}/$(package_dir superstring)"
	${EPYTHON} "${FILESDIR}/gyp-unbundle.py" \
		--inplace --unbundle \
		"superstring_core;./vendor/pcre/pcre.gyp:pcre;pcre2-16; \
			-DPCRE2_CODE_UNIT_WIDTH=16" \
		"${_s}/binding.gyp" || die

	for binmod in ${BINMODS[@]}; do
		_s="${WORKDIR}/$(package_dir ${binmod})"
		mkdir -p "${_s}/node_modules" || die
		ln -s "${nan_s}" "${_s}/node_modules/nan" || die
	done

	sed -i -e "s|{{ATOM_PREFIX}}|${EROOT%/}|g" \
		"${BUILD_DIR}/app/src/config-schema.js" || die

	sed -i -e "s|{{ATOM_SUFFIX}}|${suffix}|g" \
		"${BUILD_DIR}/app/src/config-schema.js" || die

	eapply_user
}

src_configure() {
	local binmod

	for binmod in ${BINMODS[@]}; do
		einfo "Configuring ${binmod}..."
		cd "${WORKDIR}/$(package_dir ${binmod})" || die
		enodegyp_atom configure
	done
}

src_compile() {
	local binmod
	local x
	local ctags_d="node_modules/symbols-view/vendor"
	local jobs=$(makeopts_jobs)
	local gypopts

	# Transpile any yet untranspiled files.
	ecoffeescript "${BUILD_DIR}/app/spec/*.coffee"

	gypopts="--verbose"

	if [[ ${MAKEOPTS} == *-j* && ${jobs} != 999 ]]; then
		gypopts+=" --jobs ${jobs}"
	fi

	mkdir -p "${BUILD_DIR}/modules/" || die

	for binmod in ${BINMODS[@]}; do
		einfo "Building ${binmod}..."
		cd "${WORKDIR}/$(package_dir ${binmod})" || die
		enodegyp_atom ${gypopts} build
		x=${binmod##node-}
		mkdir -p "${BUILD_DIR}/modules/${x}" || die
		cp build/Release/*.node "${BUILD_DIR}/modules/${x}" || die
	done

	# Put compiled binary modules in place
	_fix_binmods "${BUILD_DIR}/app" "apm"
	_fix_binmods "${BUILD_DIR}/app" "node_modules"

	# Remove non-Linux vendored ctags binaries
	rm "${BUILD_DIR}/app/${ctags_d}/ctags-darwin" \
	   "${BUILD_DIR}/app/${ctags_d}/ctags-win32.exe" || die

	# Re-pack app.asar
	# Keep unpack rules in sync with build/tasks/generate-asar-task.coffee
	cd "${BUILD_DIR}" || die
	x="--unpack={*.node,ctags-config,ctags-linux,**/spec/fixtures/**,**/node_modules/spellchecker/**,**/resources/atom.png}"
	xd="--unpack-dir=apm"
	easar pack "${x}" "${xd}" "app" "app.asar"

	rm -r "${BUILD_DIR}/app.asar.unpacked/apm" || die

	# Replace vendored ctags with a symlink to system ctags
	rm "${BUILD_DIR}/app.asar.unpacked/${ctags_d}/ctags-linux" || die
	ln -s "${EROOT%/}/usr/bin/ctags" \
		"${BUILD_DIR}/app.asar.unpacked/${ctags_d}/ctags-linux" || die
}

src_test() {
	local electron="$(get_electron_dir)/electron"
	local app="${BUILD_DIR}/app.asar"

	virtx "${electron}" --app="${app}" --test "${app}/spec"
}

src_install() {
	local install_dir="$(get_install_dir)"
	local suffix="$(get_install_suffix)"

	insinto "${install_dir}"

	doins "${BUILD_DIR}/app.asar"
	doins -r "${BUILD_DIR}/app.asar.unpacked"

	insinto "${install_dir}/app"
	doins -r "${BUILD_DIR}/app/apm"

	insinto "/usr/share/applications/"
	newins "${BIN_S}/usr/share/applications/$(get_atom_appname).desktop" \
		"atom${suffix}.desktop"

	insinto "/usr/share/icons/"
	doins -r "${BIN_S}/usr/share/icons/hicolor"

	exeinto "${install_dir}"
	newexe "${BUILD_DIR}/app/atom.sh" atom
	insinto "/usr/share/licenses/${PN}${suffix}"
	doins "${BIN_S}/$(get_atom_rpmdir)/resources/LICENSE.md"
	dosym "${install_dir}/atom" "/usr/bin/atom${suffix}"
	dosym "${install_dir}/app/apm/bin/apm" "/usr/bin/apm${suffix}"

	_fix_executables "${install_dir}/app/apm/bin"
	_fix_executables "${install_dir}/app/apm/node_modules/.bin"
	_fix_executables "${install_dir}/app/apm/node_modules/npm/bin"
	_fix_executables "${install_dir}/app/apm/node_modules/npm/bin/node-gyp-bin"
	_fix_executables "${install_dir}/app/apm/node_modules/node-gyp/bin"
}

pkg_postinst() {
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
}

# Helpers
# -------

# Return the installation suffix appropriate for the slot.
get_install_suffix() {
	local c=(${SLOT//\// })
	local slot=${c[0]}
	local suffix

	if [[ "${slot}" == "0" ]]; then
		suffix=""
	else
		suffix="-${slot}"
	fi

	echo -n "${suffix}"
}

# Return the upstream app name appropriate for $PV.
get_atom_appname() {
	if [[ "${PV}" == *beta* ]]; then
		echo -n "atom-beta"
	else
		echo -n "atom"
	fi
}

# Return the app installation path inside the upstream archive.
get_atom_rpmdir() {
	echo -n "usr/share/$(get_atom_appname)"
}

# Return the installation target directory.
get_install_dir() {
	echo -n "/usr/$(get_libdir)/atom$(get_install_suffix)"
}

# Return the Electron installation directory.
get_electron_dir() {
	echo -n "${EROOT%/}/usr/$(get_libdir)/electron-${ELECTRON_SLOT}"
}

# Return the directory containing appropriate Node headers
# for the required version of Electron.
get_electron_nodedir() {
	echo -n "${EROOT%/}/usr/include/electron-${ELECTRON_SLOT}/node/"
}

# Run JavaScript using Electron's version of Node.
enode_electron() {
	"$(get_electron_dir)"/node $@
}

# Run node-gyp using Electron's version of Node.
enodegyp_atom() {
	local apmpath="$(get_atom_rpmdir)/resources/app/apm"
	local nodegyp="${BIN_S}/${apmpath}/node_modules/node-gyp/bin/node-gyp.js"

	PATH="$(get_electron_dir):${PATH}" \
		enode_electron "${nodegyp}" \
			--nodedir="$(get_electron_nodedir)" $@ || die
}

# Coffee Script wrapper.
ecoffeescript() {
	local cscript="${FILESDIR}/transpile-coffee-script.js"

	# Disable shell glob expansion, as we want the coffee script
	# transpiler to do that instead.
	set -f
	echo "ecoffeescript" $@
	ATOM_HOME="${T}/.atom" ATOM_SRC_ROOT="${BUILD_DIR}/app" \
	NODE_PATH="${BUILD_DIR}/app/node_modules" \
		enode_electron "${cscript}" $@ || die
	set +f
}

# asar wrapper.
easar() {
	local asar="${WORKDIR}/$(package_dir asar)/node_modules/asar/bin/asar"
	echo "asar" $@
	enode_electron "${asar}" $@ || die
}

# Return a $WORKDIR directory for a given package name.
package_dir() {
	local binmod="${1//-/_}"
	local binmod_v="${binmod^^}_V"
	echo -n ${1}-${!binmod_v}
}

# Check if there are patches for a given package.
_have_patches_for() {
	local _patches="${1}-*.patch" _find
	_find=$(find "${FILESDIR}" -maxdepth 1 -name "${_patches}" -print -quit)
	test -n "$_find"
}

# Tarballs on registry.npmjs.org are wildly inconsistent,
# and violate the convention of having ${P} as the top directory name.
# This helper detects and fixes that.
_unpack() {
	local a="${1}"
	local b="${a%.tar.gz}"
	local p="${b#atomdep-}"
	local dir="$(tar -tzf "${DISTDIR}/${a}" | head -1 | cut -f1 -d'/')"

	unpack "${a}"

	if [[ "${dir}" != "${p}" ]]; then
		# Set the correct name for the unpacked directory.
		mv "${WORKDIR}/${dir}" "${WORKDIR}/${p}" || die
	fi
}

# Check if the binary node module is actually a valid dependency.
# Sometimes the upstream removes a dependency from package.json but
# forgets to remove the module from node_modules.
_is_valid_binmod() {
	local mod

	for mod in "${BINMODS[@]}"; do
		if [[ "${mod}" == "${1}" ]]; then
			return 0
		fi
	done

	return 1
}

# Replace binary node modules with the newly compiled versions thereof.
_fix_binmods() {
	local _dir="${2}"
	local _prefix="${1}"
	local path
	local relpath
	local modpath
	local mod
	local f
	local d
	local cruft

	(find "${_prefix}/${_dir}" -name '*.node' -print || die) \
	| while IFS= read -r path; do
		f=$(basename "${path}")
		d=$(dirname "${path}")
	    relpath=${path#${_prefix}}
		relpath=${relpath##/}
		relpath=${relpath#W${_dir}}
		modpath=$(dirname ${relpath})
		modpath=${modpath%build/Release}
		mod=$(basename ${modpath})

		_is_valid_binmod "${mod}" || continue

		# must copy here as symlinks will cause the module loading to fail
		cp -f "${BUILD_DIR}/modules/${mod}/${f}" "${path}" || die
		cruft=$(find "${d}" -name '*.a' -print)
		if [[ -n "${cruft}" ]]; then
			rm ${cruft} || die
		fi
	done
}

# Fix script permissions and shebangs to point to the correct version
# of Node.
_fix_executables() {
	local _dir="${1}"
	local _node_sb="#!$(get_electron_dir)"/node

	(find -L "${ED}/${_dir}" -maxdepth 1 -mindepth 1 -type f -print || die) \
	| while IFS= read -r f; do
		IFS= read -r shebang < "${f}"

		if [[ ${shebang} == '#!'* ]]; then
			fperms +x "${f#${ED}}"
			if [[ "${shebang}" == "#!/usr/bin/env node" || "${shebang}" == "#!/usr/bin/node" ]]; then
				einfo "Fixing node shebang in ${f#${ED}}"
				sed --follow-symlinks -i \
					-e "1s:${shebang}$:${_node_sb}:" "${f}" || die
			fi
		fi
	done || die
}
