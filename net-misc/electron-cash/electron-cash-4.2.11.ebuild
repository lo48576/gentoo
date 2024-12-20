# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="8"

PYTHON_COMPAT=( python3_{10..11} )
DISTUTILS_USE_PEP517=setuptools

PYTHON_REQ_USE="ncurses?"

inherit desktop distutils-r1 xdg-utils

MY_P="Electron-Cash-${PV}"
DESCRIPTION="Lightweight Bitcoin Cash client (BCH fork of Electrum)"
HOMEPAGE="https://github.com/Electron-Cash/Electron-Cash"
SRC_URI="https://github.com/Electron-Cash/Electron-Cash/archive/refs/tags/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="amodem cli cosign digitalbitbox email ncurses qrcode +qt5 sync vkb
	l10n_es l10n_ja l10n_pt l10n_zh-CN"
RESTRICT+=" test"

REQUIRED_USE="
	|| ( cli ncurses qt5 )
	amodem? ( qt5 )
	cosign? ( qt5 )
	digitalbitbox? ( qt5 )
	email? ( qt5 )
	qrcode? ( qt5 )
	sync? ( qt5 )
	vkb? ( qt5 )
"

BDEPEND="${DISTUTILS_DEPS}"

RDEPEND="
	dev-python/dnspython[${PYTHON_USEDEP}]
	dev-python/ecdsa[${PYTHON_USEDEP}]
	dev-python/jsonrpclib[${PYTHON_USEDEP}]
	dev-python/pathvalidate[${PYTHON_USEDEP}]
	dev-python/pbkdf2[${PYTHON_USEDEP}]
	dev-python/pyaes[${PYTHON_USEDEP}]
	dev-python/pysocks[${PYTHON_USEDEP}]
	dev-python/qrcode[${PYTHON_USEDEP}]
	dev-python/requests[${PYTHON_USEDEP}]
	dev-python/setuptools[${PYTHON_USEDEP}]
	dev-python/six[${PYTHON_USEDEP}]
	dev-python/protobuf[${PYTHON_USEDEP}]
	net-libs/stem[${PYTHON_USEDEP}]
	amodem? ( dev-python/amodem[${PYTHON_USEDEP}] )
	qrcode? ( media-gfx/zbar[v4l] )
	qt5? (
		dev-python/pyqt5[gui,widgets,${PYTHON_USEDEP}]
	)
	ncurses? ( dev-lang/python )
	dev-libs/libsecp256k1
"

distutils_enable_tests pytest

S="${WORKDIR}/${MY_P}"

DOCS="RELEASE-NOTES"

src_prepare() {
	eapply "${FILESDIR}/3.3.6-no-user-root.patch"

	# Prevent icon from being installed in the wrong location
	sed -e '/icons/d' \
		-e "s:\\(os.path.join(\\)share_dir:\\1'share':" \
		-i setup.py || die

	if use qt5; then
		pyrcc5 icons.qrc -o electroncash_gui/qt/icons_rc.py || die
	else
		sed "s|'electroncash_gui.qt',||" -i setup.py || die
	fi

	local wordlist=
	for wordlist in  \
		$(usex l10n_ja '' japanese) \
		$(usex l10n_pt '' portuguese) \
		$(usex l10n_es '' spanish) \
		$(usex l10n_zh-CN '' chinese_simplified) \
	; do
		rm -f "electroncash/wordlist/${wordlist}.txt" || die
		sed -i "/${wordlist}\\.txt/d" electroncash/mnemonic.py || die
	done

	# Remove unrequested GUI implementations:
	local gui setup_py_gui
	for gui in  \
		$(usex cli      '' stdio)  \
		$(usex qt5      '' qt   )  \
		$(usex ncurses  '' text )  \
	; do
		rm electroncash_gui/"${gui}"* -r || die
	done

	# And install requested ones...
	for gui in  \
		$(usex qt5      qt   '')  \
	; do
		setup_py_gui="${setup_py_gui}'electrum_gui.${gui}',"
	done

	sed -i "s/'electrum_gui\\.qt',/${setup_py_gui}/" setup.py || die

	local bestgui
	if use qt5; then
		bestgui=qt
	elif use ncurses; then
		bestgui=text
	else
		bestgui=stdio
	fi
	sed -i 's/^\([[:space:]]*\)\(config_options\['\''cwd'\''\] = .*\)$/\1\2\n\1config_options.setdefault("gui", "'"${bestgui}"'")\n/' "${PN}" || die

	local plugin
	# trezor requires python trezorlib module
	# keepkey requires trezor
	for plugin in  \
		$(usex amodem          '' audio_modem          ) \
		$(usex cosign          '' cosigner_pool        ) \
		$(usex digitalbitbox   '' digitalbitbox        ) \
		$(usex email           '' email_requests       ) \
		hw_wallet \
		ledger \
		keepkey \
		$(usex sync            '' labels               ) \
		trezor  \
		$(usex vkb             '' virtualkeyboard      ) \
	; do
		rm -r electroncash_plugins/"${plugin}"* || die
		sed -i "/${plugin}/d" setup.py || die
	done

	eapply_user

	distutils-r1_src_prepare
}

src_install() {
	doicon -s 128 icons/${PN}.png
	distutils-r1_src_install
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
