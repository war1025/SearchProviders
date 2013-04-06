[DBus (name="org.gnome.Shell.SearchProvider2")]
public class ColorSearch : Object {

	private static Regex hex;
	private static Regex rgb;
	private static Regex hsv;
	private static Regex hsl;

	static construct {
		ColorSearch.hex = /^#[0-9a-f]{6}$/i;
		ColorSearch.rgb = /^rgb\( *([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3}) *\)$/i;
		ColorSearch.hsv = /^hsv\( *([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3}) *\)$/i;
		ColorSearch.hsl = /^hsl\( *([0-9]{1,3}) *, *([0-9]{1,3}) *, *([0-9]{1,3}) *\)$/i;
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

		// If the result matches a html hex color, return it directly.
		// The rendering code expects data in this format.
		if(hex.match(join_term)) {
			results = {join_term.substring(1)};

		// Rgb color with each channel expected to be in [0, 255]
		// Ex: rgb(100, 55, 7)
		} else if(rgb.match(join_term, 0, out info)) {
			var red = int.parse(info.fetch(1)).clamp(0, 255);
			var green = int.parse(info.fetch(2)).clamp(0, 255);
			var blue = int.parse(info.fetch(3)).clamp(0, 255);

			results = {"%02x%02x%02x".printf(red, green, blue)};

		// Hsv color with hue [0, 360], saturation [0, 100], value [0, 100]
		// Ex: hsv(250, 75, 30)
		} else if(hsv.match(join_term, 0, out info)) {
			// These calculations were found on wikipedia
			int    hue        = int.parse(info.fetch(1)).clamp(0, 360);
			double saturation = int.parse(info.fetch(2)).clamp(0, 100) / 100.0;
			double val        = int.parse(info.fetch(3)).clamp(0, 100) / 100.0;

			double chroma = saturation * val;

			double[] rgb1 = mapHueChroma(hue, chroma);

			var m = val - chroma;

			var red   = (int) Math.round((rgb1[0] + m) * 255);
			var green = (int) Math.round((rgb1[1] + m) * 255);
			var blue  = (int) Math.round((rgb1[2] + m) * 255);

			results = {"%02x%02x%02x".printf(red, green, blue)};

		// Hsl color with hue [0, 360], saturation [0, 100], lightness [0, 100]
		// Ex: hsl(250, 75, 30)
		} else if(hsl.match(join_term, 0, out info)) {
			// These calculations were found on wikipedia
			var hue           = int.parse(info.fetch(1)).clamp(0, 360);
			double saturation = int.parse(info.fetch(2)).clamp(0, 100) / 100.0;
			double lightness  = int.parse(info.fetch(3)).clamp(0, 100) / 100.0;

			double chroma = (1.0 - Math.fabs(2 * lightness - 1.0)) * saturation;

			double[] rgb1 = mapHueChroma(hue, chroma);

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
	 * HSL and HSV both use the same mapping to go
	 * from hue and chroma to a base RGB value that is then modified further.
	 *
	 * @param hue:    The hue in degrees [0, 360]
	 * @param chroma: The chroma [0, 1]
	 **/
	private double[] mapHueChroma(int hue, double chroma) {
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

		return rgb1;
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

		// The result is a hex color of the format "rrggbb"
		int color;
		results[0].scanf("%x", out color);

		// Split it into its color parts
		uint8 red   = (uint8) ((color & 0xff0000) >> 16);
		uint8 green = (uint8) ((color & 0x00ff00) >> 8);
		uint8 blue  = (uint8) (color & 0x0000ff);

		// Gnome shell scales the pixmap to 64 X 64.
		// So if we just do one pixel it still fills the whole space.
		int width  = 1;
		int height = 1;
		int length = width * height * 3;
		uint8[] pixels = new uint8[length];
		for(int i = 0; i < length; i += 3) {
			pixels[i]     = red;
			pixels[i + 1] = green;
			pixels[i + 2] = blue;
		}

		// These are the values required by the dbus interface
		IconData iconData = { width,     // width
		                      height,    // height
		                      width * 3, // rowstride
		                      false,     // has alpha
		                      8,         // bits per channel sample
		                      3,         // number of channels
		                      pixels     // data
		                    };


		// { Store the results
		metas[0]["id"]          = "colorId";
		metas[0]["name"]        = "#%s".printf(results[0]);
		metas[0]["icon-data"]   = iconData;
		// }
	}

	/**
	 * Activate result happens when the user clicks on the result
	 *
	 * @param identifier The id we set on the meta for this result.
	 * @param terms      The search terms
	 * @param timestamp  When the search happened
	 **/
	public void activate_result(string identifier, string[] terms, uint timestamp) {

	}

	/**
	 * Launch happens when the user clicks the app icon to the left of the result.
	 *
	 * @param terms     The search terms
	 * @param timestamp When the search happened
	 **/
	public void launch_search(string[] terms, uint timestamp) {

	}

}

/**
 * Struct with data required by the SearchProvider DBus interface
 **/
protected struct IconData {
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
