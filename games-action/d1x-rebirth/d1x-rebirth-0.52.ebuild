# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils games

# DV is the Descent version. Used because the d2x-rebirth ebuild is similar.
DV="1"
DATE="20070505"
DVX=d${DV}x
FILE_START="${PN}_v${PV}-src-${DATE}"
SRC_STEM="http://www.dxx-rebirth.de/download/dxx"

DESCRIPTION="Descent Rebirth - enhanced Descent 1 engine"
HOMEPAGE="http://www.dxx-rebirth.de/"
SRC_URI="${SRC_STEM}/oss/src/${FILE_START}.tar.gz
	${SRC_STEM}/res/dxx-rebirth_icons.zip
	${SRC_STEM}/res/${PN}_hires-briefings.zip
	${SRC_STEM}/res/${PN}_hires-fonts.zip"

# Licence info at bug #117344. All 3 licences apply.
LICENSE="D1X
	GPL-2
	as-is"
SLOT="0"
KEYWORDS="~amd64 ~x86"
# awe32 (improved midi) still needs to be explicitly enabled, in d1x
IUSE="awe32 debug demo mpu401 opengl"

QA_EXECSTACK="${GAMES_BINDIR:1}/${PN}"

# physfs is only needed for d2x-rebirth
UIRDEPEND="media-libs/alsa-lib
	>=media-libs/libsdl-1.2.9
	>=media-libs/sdl-image-1.2.3-r1
	opengl? (
		virtual/glu
		virtual/opengl )
	x11-libs/libX11"
UIDEPEND="x11-proto/xf86dgaproto
	x11-proto/xf86vidmodeproto
	x11-proto/xproto"
# There is no ebuild for descent1-data
RDEPEND="${UIRDEPEND}
	demo? ( games-action/descent1-demodata )"
DEPEND="${UIRDEPEND}
	${UIDEPEND}
	dev-util/scons
	app-arch/unzip"

S=${WORKDIR}/${PN}
dir=${GAMES_DATADIR}/${DVX}

src_unpack() {
	unpack ${A}
	cd "${S}"

	# Fix sandbox violation
	sed -i \
		-e "/ENV = os.environ)/a\env.SConsignFile()" \
		-e "s:'SDL':'SDL', 'X11':" \
		SConstruct || die "sed SConstruct"

	# linux/awe_voice.h is not in recent kernels
	cp "${FILESDIR}"/awe_voice.h arch/linux/ || die
	#	-e "s:#define WANT_AWE32 0:// #define WANT_AWE32 0:"
	sed -i \
		-e "s:#include <linux/awe_voice.h>:#include \"awe_voice.h\":" \
		arch/linux/hmiplay.c || die "sed hmiplay.c awe_voice"

	# Midi music - awe32 for most SoundBlaster cards
	if use awe32 ; then
		sed -i \
			-e "s://#define WANT_AWE32 1:#define WANT_AWE32 1:" \
			arch/linux/hmiplay.c || die "sed awe32"
	elif use mpu401 ; then
		sed -i \
			-e "s://#define WANT_MPU401 1:#define WANT_MPU401 1:" \
			arch/linux/hmiplay.c || die "sed mpu401"
	fi

	# Tidy help info
	sed -i \
		-e "s:${PN}-gl/sdl:${PN}:" \
		main/inferno.c || die "sed inferno.c"
}

src_compile() {
	# Ignoring assembler, to avoid compilation issues
	local opts="no_asm=1"
	use debug && opts="${opts} debug=1"
	use opengl || opts="${opts} sdl_only=1"
	use demo && opts="${opts} shareware=1"

	# From "scons -h"
	scons \
		${opts} \
		sharepath="${dir}" \
		|| die "scons"
}

src_install() {
	local icon="${PN}.xpm"
	# Reasonable set of default options. Don't bother with ${DVX}.ini file.
	local params="-gl_trilinear -gl_anisotropy 8.0 -gl_transparency -gl_reticle 2 -fullscreen -menu_gameres -hiresfont -persistentdebris"

	local exe=${PN}-sdl
	use opengl && exe=${PN}-gl

	newgamesbin ${exe} ${PN} || die "newgamesbin ${exe}"
	games_make_wrapper ${PN}-common "${PN} ${params}"
	doicon "${WORKDIR}/${icon}" || die "doicon"
	make_desktop_entry ${PN}-common "Descent ${DV} Rebirth" "${icon}"

	insinto "${dir}"/hires
	doins "${WORKDIR}"/*.{pcx,fnt} || die

	dodoc *.txt "${WORKDIR}"/*.txt

	prepgamesdirs
}

pkg_postinst() {
	games_pkg_postinst

	if use demo ; then
		elog "${PN} has been compiled specifically for the demo data."
	else
		elog "Place the DOS data files in ${dir}"
		echo
		ewarn "Re-emerge with the 'demo' USE flag if this error is shown:"
		ewarn "   Error: Not enough strings in text file"
	fi
	echo

	if ! use opengl ; then
		elog "Add the 'opengl' USE flag, for better graphics."
	fi
	elog "To play the game with common options, run:  ${PN}-common"
	echo
}
