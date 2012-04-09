using Json; 
using Sqlite;

/**
 * Represent a point of energy.
 */
class EnergyPoint
{
	public DateTime time;
	public int		power;
}

/**
 * Energy Storage
 */
class EnergyStorage
{
	private Database db;

	// Prepared statements.
	private Statement insert_ep;

	/**
	 * Create a new Storage. 
	 */
	public EnergyStorage(string db_filename)
	{
		Sqlite.Database.open(db_filename, out db);

		// Create the DB
		const string create_db = """
			CREATE TABLE IF NOT EXISTS data (
					time 	INTEGER UNIQUE PRIMARY KEY,
					power 	INTEGER);
				""";
		// Create index
		const string create_index = """
			CREATE INDEX IF NOT EXISTS index_time ON data(time);
                """;


		db.exec(create_db);

		const string insert_db_str = """
			INSERT OR IGNORE INTO data VALUES(?, ?);	
			""";

		if(db.prepare_v2(insert_db_str,-1, out insert_ep) == 1)
		{
			GLib.error("Failed to create stmt: %s", db.errmsg());
		}
	}

	/**
	 * Add a point to the DB.
	 * If does not exist 
	 */
	private bool add_point(EnergyPoint ep)
	{
		insert_ep.bind_int64(1, ep.time.to_unix());	
		insert_ep.bind_int(2, ep.power);	

		insert_ep.step();
		insert_ep.reset();
		if(db.last_insert_rowid() > 0) return true;
		return false;
	}


	/****
	 * Load data from a json file.
	 */
	public uint parse_from_json(string filename) throws GLib.Error
	{
		uint retv = 0;
		var js = new Json.Parser();

		// Load files.
		js.load_from_file(filename);

		// 
		var node = js.get_root();

		// No data in json file. abort().
		if(node == null) return retv;

		var obj = node.get_object();

		int timeunits = (int)obj.get_int_member("dt");
		string time = obj.get_string_member("tm");
		TimeVal val = TimeVal();
		val.from_iso8601(time);
		DateTime dt = new DateTime.from_timeval_local(val);	

		var val_obj = obj.get_array_member("val");
		foreach(weak Json.Node el in val_obj.get_elements())
		{
			string? a = el.get_string();
			if(a != null && a.length > 0) { 
				EnergyPoint ep = new EnergyPoint();
				ep.time = dt;
				ep.power = int.parse(el.get_string());
				if(this.add_point(ep)) retv++;
			}
			dt = dt.add_seconds((double)60.0);

		}
		return retv;
	}

	/**
	 * 
 	 */
	public List<EnergyPoint> get_data(owned DateTime? start = null, owned DateTime? stop = null)
	{
		if(start == null) start = this.get_starting_datetime();
		if(stop == null) stop = this.get_stopping_datetime();
		List<EnergyPoint> eps = new List<EnergyPoint>();
		// Create index
		const string create_index = """
			SELECT * FROM data WHERE time >= ? AND time <= ? ORDER BY time ASC; 
                """;
		
		Statement stmt;
		db.prepare_v2(create_index, -1, out stmt);

		stmt.bind_int64(1,start.to_unix());
		stmt.bind_int64(2,stop.to_unix());

		int cols,rc=0;
		cols = stmt.column_count();
		do {

			rc = stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					EnergyPoint ep = new EnergyPoint();
					ep.time  = new GLib.DateTime.from_unix_local(stmt.column_int64(0));
					ep.power = stmt.column_int(1);
					eps.append(ep);
					break;
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);


		return eps;
	}


	public double get_average_energy(owned DateTime? start = null, owned DateTime? stop = null)
	{
		start = this.get_starting_datetime(start);
		stop = this.get_stopping_datetime(stop);
		if(start == null || stop == null || start.to_unix() == 0 || stop.to_unix() == 0) return 0.0;
		double energy = get_energy(start, stop);

		if(start.equal(stop)) return 0.0;
		return (energy*3600.0/(stop.to_unix()-start.to_unix()));
	}

	public double get_energy(owned DateTime? start = null, owned DateTime? stop = null)
	{
		if(start == null) start = this.get_starting_datetime();
		if(stop == null) stop = this.get_stopping_datetime();
		

		var eps = this.get_data(start, stop);

		if(eps == null) return 0.0;

		var first = eps.first().data;
		double val = 0.0;
		foreach(var ep in eps)
		{
			TimeSpan diff = ep.time.difference(first.time);
			// Make seconds.
			diff = diff/TimeSpan.SECOND;
			if(diff > 0)
			{
				val += (first.power)/(double)diff;
			}
			first = ep;
		}
		return val;
	}


	public DateTime? get_starting_datetime(DateTime? time = null)
	{
		// Create index
		const string create_index = """
			SELECT MIN(time) FROM data WHERE time >= ?;
		""";

		Statement stmt;
		db.prepare_v2(create_index, -1, out stmt);
		if(time != null)
			stmt.bind_int64(1,time.to_unix());
		else
			stmt.bind_int64(1,0);

		int cols,rc=0;
		cols = stmt.column_count();
		do {

			rc = stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					return new GLib.DateTime.from_unix_local(stmt.column_int64(0));
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);
		return null;
	}
	public DateTime? get_stopping_datetime(DateTime? time = null)
	{
		// Create index
		const string create_index = """
			SELECT MAX(time) FROM data WHERE time <= ?;
		""";

		Statement stmt;
		db.prepare_v2(create_index, -1, out stmt);

		if(time != null)
			stmt.bind_int64(1,time.to_unix());
		else
			stmt.bind_int64(1,int64.MAX);

		int cols,rc=0;
		cols = stmt.column_count();
		do {

			rc = stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					return new GLib.DateTime.from_unix_local(stmt.column_int64(0));
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);
		return null;
	}
}
