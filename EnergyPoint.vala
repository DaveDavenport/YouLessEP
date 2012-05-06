using Json; 
using Sqlite;

/**
 * Represent a point of energy.
 */
struct EnergyPoint
{
	public DateTime time;
	public int		power;
}

errordomain ErrorEnergyStorage {
	OPENCREATE,
	PREPARE_STATEMENT	
}
/**
 * Energy Storage
 */
class EnergyStorage
{
	private Database db;
	public string? _filename = null;
	public string? filename {get{return _filename;}}

	// Prepared statements.
	private Statement insert_ep;
	private Statement transaction_start;
	private Statement transaction_stop;
	private Statement stop_date_stmt;
	private Statement start_date_stmt;
	private Statement get_data_stmt;




	/**
	 * Create a new Storage. 
	 */
	public EnergyStorage(string db_filename) throws ErrorEnergyStorage
	{
		_filename = db_filename;
		int returnv = Sqlite.Database.open(db_filename, out db);

		if(returnv != Sqlite.OK)
		{
			throw new ErrorEnergyStorage.OPENCREATE("Failed to open/create database: %s", db.errmsg());
		}

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
		db.exec(create_index);

		const string insert_db_str = """
			INSERT OR IGNORE INTO data VALUES(?, ?);	
			""";

		if(db.prepare_v2(insert_db_str,-1, out insert_ep) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}


		const string transaction_start_str = """
				BEGIN TRANSACTION;
			""";
		if(db.prepare_v2(insert_db_str,-1, out insert_ep) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}
		const string transaction_stop_str = """
				COMMIT;
			""";
		if(db.prepare_v2(transaction_start_str,-1, out transaction_start) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}
		if(db.prepare_v2(transaction_stop_str,-1, out transaction_stop) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}

		const string stop_date_stmt_str = """
			SELECT MAX(time) FROM data WHERE time <= ?;
		""";

		if(db.prepare_v2(stop_date_stmt_str,-1, out stop_date_stmt) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}

		const string start_date_stmt_str = """
			SELECT MIN(time) FROM data WHERE time >= ?;
		""";

		if(db.prepare_v2(start_date_stmt_str,-1, out start_date_stmt) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}

		const string get_data_stmt_str = """
			SELECT * FROM data WHERE time >= ? AND time <= ? ORDER BY time ASC; 
                """;
		if(db.prepare_v2(get_data_stmt_str,-1, out get_data_stmt) == 1)
		{
			throw new ErrorEnergyStorage.PREPARE_STATEMENT("Failed to create stmt: %s", db.errmsg());
		}
	}

	/**
	 * Add a point to the DB.
	 * If does not exist 
	 */
	private bool add_point(EnergyPoint ep)
	{
		var lir = db.last_insert_rowid();
		insert_ep.bind_int64(1, ep.time.to_unix());	
		insert_ep.bind_int(2, ep.power);	

		insert_ep.step();
		insert_ep.reset();
		if(db.last_insert_rowid() != lir) return true;
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

		// check if all values are zero, if so, do not store.
		bool nonzero = false;
		foreach(weak Json.Node el in val_obj.get_elements())
		{
			string? a = el.get_string();
			if(a != null && a.length > 0) { 
				if(int.parse(el.get_string()) >0)
				{
					nonzero = true;
				}
			}
		}
		if(!nonzero) return retv;
		foreach(weak Json.Node el in val_obj.get_elements())
		{
			string? a = el.get_string();
			if(a != null && a.length > 0) { 
				EnergyPoint ep = EnergyPoint();
				ep.time = dt;
				ep.power = int.parse(el.get_string());
				if(this.add_point(ep)) retv++;
			}
			dt = dt.add_seconds((double)timeunits);
		}
		return retv;
	}


	public void start_transaction()
	{
		transaction_start.step();
	}
	public void stop_transaction()
	{
		transaction_stop.step();
	}

	/**
	 * 
 	 */
	public List<EnergyPoint?> get_data(owned DateTime? start = null, owned DateTime? stop = null)
	{
		if(start == null) start = this.get_starting_datetime();
		if(stop == null) stop = this.get_stopping_datetime();
		List<EnergyPoint?> eps = new List<EnergyPoint?>();


		get_data_stmt.reset();

		get_data_stmt.bind_int64(1,start.to_unix());
		get_data_stmt.bind_int64(2,stop.to_unix());

		int rc=0;
		do {

			rc = get_data_stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					EnergyPoint ep = EnergyPoint();
					ep.time  = new GLib.DateTime.from_unix_local(get_data_stmt.column_int64(0));
					ep.power = get_data_stmt.column_int(1);
					eps.prepend(ep);
					break;
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);
		eps.reverse();

		return eps;
	}


	public double get_average_energy(owned DateTime? start = null, owned DateTime? stop = null)
	{
		start = this.get_starting_datetime(start);
		stop = this.get_stopping_datetime(stop);
		if(start == null || stop == null || start.to_unix() == 0 || stop.to_unix() == 0) return 0.0;
		TimeSpan span = 0; 
		double energy = get_energy(start, stop, out span);

		if(start.equal(stop)) return 0.0;
		return (energy*3600.0/(span/TimeSpan.SECOND));  //(stop.to_unix()-start.to_unix()));
	}

	public double get_energy(owned DateTime? start = null, owned DateTime? stop = null, out TimeSpan elapsed_time)
	{
		if(start == null) start = this.get_starting_datetime();
		if(stop == null) stop = this.get_stopping_datetime();
		

		var eps = this.get_data(start, stop);

		if(eps == null) return 0.0;


		var first = eps.first().data;
		double val = 0.0;
		foreach(var ep in eps)
		{
			// per one minute
			TimeSpan diff = 60*TimeSpan.SECOND;//ep.time.difference(first.time);
			elapsed_time += diff;
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
		// Reset the query.
		start_date_stmt.reset();

		if(time != null)
			start_date_stmt.bind_int64(1,time.to_unix());
		else
			start_date_stmt.bind_int64(1,0);

		int rc=0;
		do {

			rc = start_date_stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					return new GLib.DateTime.from_unix_local(start_date_stmt.column_int64(0));
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);
		return null;
	}

	public DateTime? get_stopping_datetime(DateTime? time = null)
	{
		// Reset the query.
		stop_date_stmt.reset();

		if(time != null)
			stop_date_stmt.bind_int64(1,time.to_unix());
		else
			stop_date_stmt.bind_int64(1,int64.MAX);

		int rc=0;
		do {

			rc = stop_date_stmt.step();

			switch(rc)
			{
				case Sqlite.DONE:
					break;
				case Sqlite.ROW:
					return new GLib.DateTime.from_unix_local(stop_date_stmt.column_int64(0));
				default:
					stdout.printf ("Error: %d, %s\n", rc, db.errmsg ());
					break;
			}
		} while (rc == Sqlite.ROW);

		return null;
	}
}
