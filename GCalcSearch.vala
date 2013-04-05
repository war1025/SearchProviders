[DBus (name="org.gnome.Shell.SearchProvider2")]
public class GCalcSearch : Object {

	private static Gee.HashMap<string, int> bases;
	private static Gee.HashMap<int, string> prefixes;

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

	public void get_initial_result_set(string[] terms, out string[] results) {
		var expr = string.joinv(" ", terms);
		if(/([0-9+\-*\/^!]|'pi')+/i.match(expr)) {
			results = {expr};
		} else {
			results = {};
		}
	}

	public void get_subsearch_result_set(string[] previous, string[] terms, out string[] results) {
		this.get_initial_result_set(terms, out results);
	}

	public void get_result_metas(string[] results, out HashTable<string, Variant>[] metas) {
		metas    = new HashTable<string, Variant>[1];
		metas[0] = new HashTable<string, Variant>(str_hash, str_equal);


		string expr = results[0];

		expr = pi.replace(expr, expr.length, 0, "π");
		expr = octal.replace(expr, expr.length, 0, "\\1\\2₈");
		expr = hex.replace(expr, expr.length, 0, "\\1\\2₁₆");
		expr = binary.replace(expr, expr.length, 0, "\\1\\2₂");
		expr = radians.replace(expr, expr.length, 0, "\\1((180/π) *");
		expr = radians2.replace(expr, expr.length, 0, "(π/180) * a\\1(");

		var final_base = 10;

		MatchInfo info;
		if(changeBase.match(expr, 0, out info)) {
			final_base = bases[info.fetch(1)];
		   	expr = changeBase.replace(expr, expr.length, 0, "");
		}

		string output;

		try {
			Process.spawn_sync(null, {"gnome-calculator", "-s", expr},
							   null, SpawnFlags.SEARCH_PATH, null, out output);
		} catch(SpawnError s) {
		}

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

		metas[0]["id"]          = "calculatorId";
		metas[0]["name"]        = expr;
		metas[0]["description"] = output;
		metas[0]["gicon"]       = "None";

		this.lastSearch = expr;
		this.lastResult = output;
	}

	public void activate_result(string identifier, string[] terms, uint timestamp) {
		var clipboard = Gtk.Clipboard.get_for_display(Gdk.Display.get_default(),
												      Gdk.SELECTION_CLIPBOARD);
		clipboard.set_text(this.lastResult, this.lastResult.length);

	}

	public void launch_search(string[] terms, uint timestamp) {
		Pid child_pid;
		try {
			Process.spawn_async(null, {"gnome-calculator", "-e", this.lastSearch},
							    null, SpawnFlags.SEARCH_PATH, null, out child_pid);
		} catch(SpawnError s) {
		}

	}

	private string change_base(string numberStr, int toBase) {

		string[] convertTable = {"0", "1", "2", "3", "4", "5", "6", "7",
		       		             "8", "9", "A", "B", "C", "D", "E", "F"};

		int number = (int) double.parse(numberStr);

		var outStr = new StringBuilder();
		var term = 1;
		while(term <= number) {
			term *= toBase;
		}
		term /= toBase;
		while(term > 1) {
			outStr.append(convertTable[number / term]);
			number = number % term;
			term /= toBase;
		}
		outStr.append(convertTable[number]);
		if(outStr.len == 0) {
			outStr.assign("0");
		}

		return outStr.str;
	}

}

void main(string[] args) {
	Gtk.init(ref args);
	Bus.own_name(BusType.SESSION, "org.wrowclif.TestSearch", BusNameOwnerFlags.NONE,
				(c) => {c.register_object("/org/wrowclif/TestSearch", new GCalcSearch());},
				() => {},
				() => stderr.printf ("Could not aquire name\n"));

	new MainLoop().run();
}
