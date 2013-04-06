
all: gcalc color

install-gcalc: GCalcSearch gcalc-searchprovider.ini org.wrowclif.GCalcSearch.service
	cp ./gcalc-searchprovider.ini /usr/share/gnome-shell/search-providers/
	cp ./org.wrowclif.GCalcSearch.service /usr/share/dbus-1/services/
	cp ./GCalcSearch /usr/bin/gcalc-searchprovider

uninstall-gcalc:
	rm -f /usr/share/gnome-shell/search-providers/gcalc-searchprovider.ini
	rm -f /usr/share/dbus-1/services/org.wrowclif.GCalcSearch.service
	rm -f /usr/bin/gcalc-searchprovider

restart-gcalc:
	killall gcalc-searchprovider

gcalc:
	valac-0.18 --pkg gio-2.0 --pkg gee-1.0 --pkg gtk+-3.0 --pkg gdk-3.0 --enable-experimental ./GCalcSearch.vala

install-color: ColorSearch color-searchprovider.ini org.wrowclif.ColorSearch.service
	cp ./color-searchprovider.ini /usr/share/gnome-shell/search-providers/
	cp ./org.wrowclif.ColorSearch.service /usr/share/dbus-1/services/
	cp ./ColorSearch /usr/bin/color-searchprovider

uninstall-color:
	rm -f /usr/share/gnome-shell/search-providers/color-searchprovider.ini
	rm -f /usr/share/dbus-1/services/org.wrowclif.ColorSearch.service
	rm -f /usr/bin/color-searchprovider

restart-color:
	killall color-searchprovider

color:
	valac-0.18 --pkg gio-2.0 --pkg gee-1.0 --enable-experimental -X -lm ./ColorSearch.vala
