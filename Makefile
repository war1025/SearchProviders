DESTDIR =
PREFIX = /usr

INSTALL_DATA=install -m644
INSTALL_PROGRAM=install -m755
MKDIR=mkdir -p -m 755

all: gcalc color

install-gcalc: GCalcSearch gcalc-searchprovider.ini org.wrowclif.GCalcSearch.service
	${MKDIR} ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers
	${MKDIR} ${DESTDIR}${PREFIX}/share/dbus-1/services
	${MKDIR} ${DESTDIR}${PREFIX}/bin

	${INSTALL_DATA} ./gcalc-searchprovider.ini ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers/
	${INSTALL_DATA} ./org.wrowclif.GCalcSearch.service ${DESTDIR}${PREFIX}/share/dbus-1/services/
	${INSTALL_PROGRAM} ./GCalcSearch ${DESTDIR}${PREFIX}/bin/gcalc-searchprovider

uninstall-gcalc:
	rm -f ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers/gcalc-searchprovider.ini
	rm -f ${DESTDIR}${PREFIX}/share/dbus-1/services/org.wrowclif.GCalcSearch.service
	rm -f ${DESTDIR}${PREFIX}/bin/gcalc-searchprovider

restart-gcalc:
	killall gcalc-searchprovider

gcalc:
	valac --pkg gio-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg gdk-3.0 --enable-experimental ./GCalcSearch.vala

install-color: ColorSearch color-searchprovider.ini org.wrowclif.ColorSearch.service
	${MKDIR} ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers
	${MKDIR} ${DESTDIR}${PREFIX}/share/dbus-1/services
	${MKDIR} ${DESTDIR}${PREFIX}/bin

	${INSTALL_DATA} ./color-searchprovider.ini ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers/
	${INSTALL_DATA} ./org.wrowclif.ColorSearch.service ${DESTDIR}${PREFIX}/share/dbus-1/services/
	${INSTALL_PROGRAM} ./ColorSearch ${DESTDIR}${PREFIX}/bin/color-searchprovider

uninstall-color:
	rm -f ${DESTDIR}${PREFIX}/share/gnome-shell/search-providers/color-searchprovider.ini
	rm -f ${DESTDIR}${PREFIX}/share/dbus-1/services/org.wrowclif.ColorSearch.service
	rm -f ${DESTDIR}${PREFIX}/bin/color-searchprovider

restart-color:
	killall color-searchprovider

color:
	valac --pkg gio-2.0 --pkg gee-0.8 --enable-experimental -X -lm ./ColorSearch.vala
