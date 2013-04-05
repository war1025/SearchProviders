
all: gcalc

gcalc:
	valac-0.18 --pkg gio-2.0 --pkg gee-1.0 --pkg gtk+-3.0 --pkg gdk-3.0 --enable-experimental ./GCalcSearch.vala
