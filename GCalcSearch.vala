[DBus (name="org.gnome.Shell.SearchProvider2")]
public class GCalcSearch : Object {

	private static Gee.HashMap<string, int> bases;
	private static Gee.HashMap<int, string> prefixes;

	private static Regex isCalcString;
	private static Regex pi;
	private static Regex octal;
	private static Regex binary;
	private static Regex hex;
	private static Regex radians;
	private static Regex radians2;
	private static Regex changeBase;

	private string lastSearch;
	private string lastResult;

	static construct {
		GCalcSearch.bases = new Gee.HashMap<string, int>();
		GCalcSearch.bases["hex"]    = 16;
		GCalcSearch.bases["octal"]  = 8;
		GCalcSearch.bases["binary"] = 2;

		GCalcSearch.prefixes = new Gee.HashMap<int, string>();
		GCalcSearch.prefixes[16] = "0x";
		GCalcSearch.prefixes[10] = "";
		GCalcSearch.prefixes[8]  = "0";
		GCalcSearch.prefixes[2]  = "0b";

		GCalcSearch.isCalcString = /([0-9+\-*\/^!]|'pi')+/i;

		GCalcSearch.pi     = /'pi'/i;
		GCalcSearch.octal  = /(^|\s|[^0-9a-fA-Fxb\.]+)0([0-7]+)/;
		GCalcSearch.binary = /(^|\s|[^0-9a-fA-Fxb]+)0b([0-1]+)/;
		GCalcSearch.hex    = /(^|\s|[^0-9a-fA-Fxb]+)0x([0-9a-fA-F]+)/;

		GCalcSearch.radians  = /r(sin|cos|tan)\(/;
		GCalcSearch.radians2 = /ra(sin|cos|tan)\(/;

		GCalcSearch.changeBase = /in (hex|octal|binary)$/i;
	}

	public GCalcSearch() {
		lastSearch = "";
		lastResult = "";
	}

	/**
	 * Called when a search happens.
	 *
	 * @param terms    The current search terms
	 * @param results  Where to store results we find
	 **/
	public void get_initial_result_set(string[] terms, out string[] results) {
		// Join everything together into a single string
		var expr = string.joinv(" ", terms);

		// Create a result if the string looks like it could be a calculation
		if(isCalcString.match(expr)) {
			results = {expr};
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

		// We only ever do one calculation at a time.
		string expr = results[0];

		// Replace 'pi' with the unicode character
		expr = pi.replace(expr, expr.length, 0, "π");
		// Gnome calculator uses unicode suffixes, so replace those
		expr = octal.replace(expr, expr.length, 0, "\\1\\2₈");
		expr = hex.replace(expr, expr.length, 0, "\\1\\2₁₆");
		expr = binary.replace(expr, expr.length, 0, "\\1\\2₂");
		// Do some inline conversion to allow for trig functions using radians.
		// (rsin, rcos, rtan, etc.)
		expr = radians.replace(expr, expr.length, 0, "\\1((180/π) *");
		expr = radians2.replace(expr, expr.length, 0, "(π/180) * a\\1(");

		// { Figure out if the user wants the result in a different base
		var final_base = 10;

		MatchInfo info;
		if(changeBase.match(expr, 0, out info)) {
			final_base = bases[info.fetch(1)];
		   	expr = changeBase.replace(expr, expr.length, 0, "");
		}
		// }

		// { Do the calculation
		string output;

		try {
			Process.spawn_sync(null, {"gnome-calculator", "-s", expr},
							   null, SpawnFlags.SEARCH_PATH, null, out output);
		} catch(SpawnError s) {
		}
		// }

		// { Change bases if needed
		if(final_base != 10) {
			var negative = output[0] == '−';
			if(negative) {
				output = output.substring(1);
			}
			output = this.change_base(output, final_base);
			output = prefixes[final_base] + output;
			if(negative) {
				output = "−%s".printf(output);
			}
		}
		// }

		// { Store the results
		//   Note: There is a bug in gnome-shell that makes results not show up if
		//         a value isn't set for "gicon", so put in a bogus value.
		bool has_value = output.length > 0;

		metas = new HashTable<string, Variant>[has_value ? 1 : 0];
		if(has_value) {
			metas[0]                = new HashTable<string, Variant>(str_hash, str_equal);
			metas[0]["id"]          = "calculatorId";
			metas[0]["name"]        = expr;
			metas[0]["description"] = output;
			metas[0]["gicon"]       = "None";
		}

		this.lastSearch = has_value ? expr : "";
		this.lastResult = has_value ? output : "";
		// }
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
		if(this.lastResult.length > 0) {
			var clipboard = Gtk.Clipboard.get_for_display(Gdk.Display.get_default(),
														  Gdk.SELECTION_CLIPBOARD);
			clipboard.set_text(this.lastResult, this.lastResult.length);
		}
	}

	/**
	 * Launch happens when the user clicks the app icon to the left of the result.
	 * We launch gnome calculator with the most recent search expression
	 *
	 * @param terms     The search terms
	 * @param timestamp When the search happened
	 **/
	public void launch_search(string[] terms, uint timestamp) {
		if(this.lastSearch.length > 0) {
			Pid child_pid;
			try {
				Process.spawn_async(null, {"gnome-calculator", "-e", this.lastSearch},
									null, SpawnFlags.SEARCH_PATH, null, out child_pid);
			} catch(SpawnError s) {
			}
		}
	}

	/**
	 * Changes the base of the result string to the given base
	 *
	 * @param numberStr The string value of the result number.
	 * @param toBase    The base to convert the result to.
	 *
	 * @return String version of the result in the requested base
	 **/
	private string change_base(string numberStr, int toBase) {
		// We do the conversion manually rather than using a library
		// (It would probably be a decent idea to find something else to do this for us.)

		// Map from int value to the string for that value.
		string[] convertTable = {"0", "1", "2", "3", "4", "5", "6", "7",
		       		             "8", "9", "A", "B", "C", "D", "E", "F"};

		// The value may have a decimal, but we only do base conversion on the
		// integer portion.
		int number = (int) double.parse(numberStr);

		// { Figure out the smallest power of the base that the number is less than
		var outStr = new StringBuilder();
		var term = 1;
		while(term <= number) {
			term *= toBase;
		}
		term /= toBase;
		// }

		// { Convert the number
		while(term > 1) {
			// Add to the result string
			outStr.append(convertTable[number / term]);
			// Find the remainder
			number = number % term;
			// Move to the next smaller term
			term /= toBase;
		}
		// The whle loop exits before the final value is added to the result string
		outStr.append(convertTable[number]);
		// }

		return outStr.str;
	}

}

void main(string[] args) {
	// We use the clipboard so we need to initialize Gtk
	Gtk.init(ref args);
	Bus.own_name(BusType.SESSION, "org.wrowclif.GCalcSearch", BusNameOwnerFlags.NONE,
				(c) => {c.register_object("/org/wrowclif/GCalcSearch", new GCalcSearch());},
				() => {},
				() => stderr.printf ("Could not aquire name\n"));

	new MainLoop().run();
}
