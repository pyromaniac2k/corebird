


class User {
	/** The user's id */
	private static int64 id;
	/** screen_name, unique per user, e.g. baedert(always written as @baedert) */
	public static string screen_name;
	/** Normal name like 'Chuck Norris' */
	public static string name;
	private static string avatar_name = "no_profile_pic.png";
	public static string avatar_url;


	public static string get_avatar_path(){
		return Utils.get_user_file_path("assets/user/"+avatar_name);
	}


	/**
	 * Loads the user's cached data from the database.
	 */
	public static void load(){
		try{
			SQLHeavy.Query query = new SQLHeavy.Query(Corebird.db,
				"SELECT screen_name, avatar_name, avatar_url, id FROM `user`;");
			SQLHeavy.QueryResult res = query.execute();
			User.screen_name = res.fetch_string(0);
			User.avatar_name = res.fetch_string(1);
			User.avatar_url  = res.fetch_string(2);
			User.id          = res.fetch_int64(3);
		}catch(SQLHeavy.Error e){
			error("Error while loading the user: %s", e.message);
		}
	}

	/**
	 * Updates the users's profile info.
	 *
	 * @param avatar_widget The widget to update if the avatar has changed.
	 */
	public static async void update_info(Gtk.Image? avatar_widget, bool use_name = false){
		var img_call = Twitter.proxy.new_call();
		img_call.set_function("1.1/users/show.json");
		img_call.set_method("GET");
		if(use_name || id == 0)
			img_call.add_param("screen_name", User.screen_name);
		else
			img_call.add_param("user_id", User.id.to_string());

		img_call.add_param("include_entities", "false");
		img_call.invoke_async.begin(null, (obj, res) => {
			try{
				img_call.invoke_async.end(res);
			} catch (GLib.Error e){
				warning("Error while ending img_call: %s", e.message);
				Utils.show_error_dialog(e.message);
				return;
			}

			string back = img_call.get_payload();
			var parser = new Json.Parser();
			try{
				parser.load_from_data(back);
			}catch(GLib.Error e){
				warning("Error while updating profile: %s", e.message);
				return;
			}
			var root = parser.get_root().get_object();
			User.name = root.get_string_member("name");
			int64 id = root.get_int_member("id");
			User.id = id;
			string avatar_url = root.get_string_member("profile_image_url");
			string avatar_name = Utils.get_avatar_name(avatar_url);
			message(@"Received ID: $id");

			// Check if the avatar of the user has changed.
			if (avatar_name != User.avatar_name
			    	|| !FileUtils.test(get_avatar_path(), FileTest.EXISTS)){

				message("Downloading new avatar...");
				//TODO: Find better variable names here
				string dest_path = Utils.get_user_file_path("assets/user/"+avatar_name);
				string big_dest  = Utils.get_user_file_path("assets/avatars/"+avatar_name);
				var session = new Soup.SessionAsync();
				var msg = new Soup.Message("GET", avatar_url);
				session.send_message(msg);

				string type = Utils.get_file_type(avatar_name);

				try{
					var data_stream = new MemoryInputStream.from_data(
									(owned)msg.response_body.data,null);
					var pixbuf = new Gdk.Pixbuf.from_stream(data_stream);
					pixbuf.save(big_dest, type);
					double scale_x = 24.0 / pixbuf.get_width();
					double scale_y = 24.0 / pixbuf.get_height();
					var scaled_pixbuf = new Gdk.Pixbuf(Gdk.Colorspace.RGB, false,
					                                   8, 24, 24);
					pixbuf.scale(scaled_pixbuf, 0, 0, 24, 24, 0, 0, scale_x, scale_y,
					             Gdk.InterpType.HYPER);
					scaled_pixbuf.save(dest_path, type);
				} catch(GLib.Error e) {
					critical("Error while downloading/scaling avatar: %s", e.message);
				}

				if(avatar_widget != null){
					avatar_widget.set_from_file(dest_path);
					avatar_widget.queue_draw();
				}

				try{
					Corebird.db.execute(@"UPDATE `user` SET `avatar_name`='$avatar_name',`avatar_url`='$avatar_url',`id`='$id';");
				}catch(SQLHeavy.Error e){
					warning("Error while setting the new avatar_name: %s", e.message);
				}
				message("Updated the avatar image!");
				User.avatar_name = avatar_name;
				User.avatar_url	 = avatar_url;
			}
		});
	}





	/**
	 * Simply returns the id of the user.
	 *
	 * @return The user's ID.
	 */
	public static int64 get_id(){
		return id;
	}
}