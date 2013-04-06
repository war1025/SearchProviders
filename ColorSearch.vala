[DBus (name="org.gnome.Shell.SearchProvider2")]
public class ColorSearch : Object {

	private static Regex hex;
	private static Regex rgb;
	private static Regex hsv;
	private static Regex hsl;

	static construct {
		ColorSearch.hex = /^#[0-9a-f]{6}$/i;
		ColorSearch.rgb = /^rgb\( *([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3}) *\)$/i;
		ColorSearch.hsv = /^hsv\(([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3})\)$/i;
		ColorSearch.hsl = /^hsl\(([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3})\)$/i;
	}

	public ColorSearch() {

	}

	/**
	 * Called when a search happens.
	 *
	 * @param terms    The current search terms
	 * @param results  Where to store results we find
	 **/
	public void get_initial_result_set(string[] terms, out string[] results) {
		var join_term = string.joinv(" ", terms);
		MatchInfo info;

		if(hex.match(join_term)) {
			results = {join_term.substring(1)};

		} else if(rgb.match(join_term, 0, out info)) {
			var red = int.parse(info.fetch(1)).clamp(0, 255);
			var green = int.parse(info.fetch(2)).clamp(0, 255);
			var blue = int.parse(info.fetch(3)).clamp(0, 255);

			results = {"%02x%02x%02x".printf(red, green, blue)};

		} else if(hsv.match(join_term, 0, out info)) {
			var hue           = int.parse(info.fetch(1)).clamp(0, 360);
			double saturation = int.parse(info.fetch(2)).clamp(0, 100) / 100.0;
			double val        = int.parse(info.fetch(3)).clamp(0, 100) / 100.0;

			double chroma = saturation * val;

			double hue_prime = hue / 60.0;

			double x = chroma * (1 - Math.fabs(Math.fmod(hue_prime, 2) - 1));

			double[] rgb1;

			if(hue_prime < 1) {
				rgb1 = {chroma, x, 0.0};
			} else if(hue_prime < 2) {
				rgb1 = {x, chroma, 0.0};
			} else if(hue_prime < 3) {
				rgb1 = {0.0, chroma, x};
			} else if(hue_prime < 4) {
				rgb1 = {0.0, x, chroma};
			} else if(hue_prime < 5) {
				rgb1 = {x, 0.0, chroma};
			} else {
				rgb1 = {chroma, 0.0, x};
			}

			var m = val - chroma;

			var red   = (int) Math.round((rgb1[0] + m) * 255);
			var green = (int) Math.round((rgb1[1] + m) * 255);
			var blue  = (int) Math.round((rgb1[2] + m) * 255);

			results = {"%02x%02x%02x".printf(red, green, blue)};

		} else if(hsl.match(join_term, 0, out info)) {
			var hue           = int.parse(info.fetch(1)).clamp(0, 360);
			double saturation = int.parse(info.fetch(2)).clamp(0, 100) / 100.0;
			double lightness  = int.parse(info.fetch(3)).clamp(0, 100) / 100.0;

			double chroma = (1.0 - Math.fabs(2 * lightness - 1.0)) * saturation;

			double hue_prime = hue / 60.0;

			double x = chroma * (1 - Math.fabs(Math.fmod(hue_prime, 2) - 1));

			double[] rgb1;

			if(hue_prime < 1) {
				rgb1 = {chroma, x, 0.0};
			} else if(hue_prime < 2) {
				rgb1 = {x, chroma, 0.0};
			} else if(hue_prime < 3) {
				rgb1 = {0.0, chroma, x};
			} else if(hue_prime < 4) {
				rgb1 = {0.0, x, chroma};
			} else if(hue_prime < 5) {
				rgb1 = {x, 0.0, chroma};
			} else {
				rgb1 = {chroma, 0.0, x};
			}

			var m = lightness - 0.5 * chroma;

			var red   = (int) Math.round((rgb1[0] + m) * 255);
			var green = (int) Math.round((rgb1[1] + m) * 255);
			var blue  = (int) Math.round((rgb1[2] + m) * 255);

			results = {"%02x%02x%02x".printf(red, green, blue)};
		} else {
			results = {};
		}
	}

	/**
	 * Called when a partial search has already occurred to narrow the results
	 *
	 * @param previous The previous search terms
	 * @param terms    The current search terms
	 * @param results  Where to store results we find
	 **/
	public void get_subsearch_result_set(string[] previous, string[] terms, out string[] results) {
		this.get_initial_result_set(terms, out results);
	}

	/**
	 * Called after we decide we have a result to convert it into something the
	 * shell will display.
	 *
	 * @param results The results we found
	 * @param metas   Where we store the meta values we create
	 **/
	public void get_result_metas(string[] results, out HashTable<string, Variant>[] metas) {
		metas    = new HashTable<string, Variant>[1];
		metas[0] = new HashTable<string, Variant>(str_hash, str_equal);

		int color;
		results[0].scanf("%x", out color);

		uint8 red   = (uint8) ((color & 0xff0000) >> 16);
		uint8 green = (uint8) ((color & 0x00ff00) >> 8);
		uint8 blue  = (uint8) (color & 0x0000ff);

		int width = 64;
		int height = 64;
		int length = width * height * 3;
		uint8[] pixels = new uint8[length];
		for(int i = 0; i < length; i += 3) {
			pixels[i]     = red;
			pixels[i + 1] = green;
			pixels[i + 2] = blue;
		}

		IconData iconData = {   width,
								height,
								width * 3,
								false,
								8,
								3,
								pixels};


		// { Store the results
		//   Note: There is a bug in gnome-shell that makes results not show up if
		//         a value isn't set for "gicon", so put in a bogus value.
		metas[0]["id"]          = "calculatorId";
		metas[0]["name"]        = "#%s".printf(results[0]);
		metas[0]["icon-data"]   = iconData;
	}

	/**
	 * Activate result happens when the user clicks on the result
	 * We copy the calculation result to the clipboard.
	 *
	 * @param identifier The id we set on the meta for this result.
	 * @param terms      The search terms
	 * @param timestamp  When the search happened
	 **/
	public void activate_result(string identifier, string[] terms, uint timestamp) {

	}

	/**
	 * Launch happens when the user clicks the app icon to the left of the result.
	 * We launch gnome calculator with the most recent search expression
	 *
	 * @param terms     The search terms
	 * @param timestamp When the search happened
	 **/
	public void launch_search(string[] terms, uint timestamp) {

	}

}

struct IconData {
	int width;
	int height;
	int rowStride;
	bool hasAlpha;
	int bitsPerSample;
	int channels;
	uint8[] data;
}

void main(string[] args) {
	Bus.own_name(BusType.SESSION, "org.wrowclif.ColorSearch", BusNameOwnerFlags.NONE,
				(c) => {c.register_object("/org/wrowclif/ColorSearch", new ColorSearch());},
				() => {},
				() => stderr.printf ("Could not aquire name\n"));

	new MainLoop().run();
}
