/*
 * This file is part of QSubber.
 *
 * QSubber is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * QSubber is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with QSubber.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace QSubber {
    [GtkTemplate(ui = "/org/imvictor/qsubber/qsubber-window.ui")]
    class Window : Gtk.ApplicationWindow {
        [GtkChild]
        private Gtk.Entry mediaEntry;

        [GtkChild]
        private Gtk.Entry nameEntry;

        [GtkChild]
        private Gtk.Entry seasonEntry;

        [GtkChild]
        private Gtk.Entry episodeEntry;

        [GtkChild]
        private Gtk.ListStore subtitlesList;

        [GtkChild]
        private Gtk.TreeSelection selectedSubtitle;

        public string selected_lang {
            get { return this.get_action_state("search-lang").get_string(); }
        }

        public Window(Gtk.Application application) {
            GLib.Object(application: application);

            Application.get_default().current_file_changed.connect(current_file_changed);

            Application.get_default().os.new_sublist.connect(sublist_updated);

            SimpleAction act_set_lang = new SimpleAction.stateful("search-lang", VariantType.STRING, new Variant.string("pob"));
            this.add_action(act_set_lang);
        }

        public void current_file_changed(File* file) {
            mediaEntry.text = file->get_path();

            try {
                Regex[] exps = {
                    new Regex("([a-zA-Z0-9. ]+)[ -_.]+[Ss]([0-9]{0,2})[Ee]([0-9]{0,2})"),
                    new Regex("([a-zA-Z0-9. ]+)[ -_.]+([0-9]+)[Xx]([0-9]+)"),
                    new Regex("([a-zA-Z0-9. ]+)[ -_.]+([0-9]{1,2})([0-9]{2})")
                };

                foreach (Regex exp in exps) {
                    string filename = file->get_basename();

                    if (exp.match(filename)) {
                        string[] data = exp.split(filename);

                        nameEntry.text = data[1].replace(".", " ");
                        seasonEntry.text = data[2];
                        episodeEntry.text = data[3];

                        break;
                    }
                }
            } catch (RegexError e) {
                stderr.printf("Failed to build regex due: %s\n", e.message);
            }
        }

        public void sublist_updated(Variant subs) {
            subtitlesList.clear();

            VariantIter iter = subs.iterator();

            Variant sub;
            while (iter.next("v", out sub)) {
                Gtk.TreeIter it;

                subtitlesList.append(out it);
                subtitlesList.set(it,
                                  0, sub.lookup_value("SubFileName", VariantType.STRING).get_string(),
                                  1, Utils.pretty_print_size(sub.lookup_value("SubSize", VariantType.STRING).get_string()),
                                  2, sub.lookup_value("SubDownloadLink", VariantType.STRING).get_string());
            }
        }

        [GtkCallback]
        public void openButton_clicked_cb() {
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog("Select Media File",
                                                                      this,
                                                                      Gtk.FileChooserAction.OPEN,
                                                                      "_Cancel", Gtk.ResponseType.CANCEL,
                                                                      "_Open", Gtk.ResponseType.ACCEPT);

            if (chooser.run() == Gtk.ResponseType.ACCEPT) {
                Application.get_default().current_file = chooser.get_file();
            }

            chooser.close();
        }

        [GtkCallback]
        public void downloadButton_clicked_cb() {
            Gtk.TreeModel _;
            Gtk.TreeIter iter;

            if (selectedSubtitle.get_selected(out _, out iter)) {
                string url;

                subtitlesList.get(iter, 2, out url);

                Application.get_default().os.download(url);
            }
        }

        [GtkCallback]
        public void hashButton_clicked_cb() {
            if (Application.get_default().current_file == null)
                return;

            VariantBuilder search = new VariantBuilder(VariantType.ARRAY);

            search.add("{sv}", "moviehash", new Variant("s", Utils.calculate_hash_for_file(Application.get_default().current_file)));

            Application.get_default().os.search(search);
        }

        [GtkCallback]
        public void sizeButton_clicked_cb() {
            if (Application.get_default().current_file == null)
                return;

            try {
                FileInfo info = Application.get_default().current_file.query_info("*", FileQueryInfoFlags.NONE);

                VariantBuilder search = new VariantBuilder(VariantType.ARRAY);

                search.add("{sv}", "moviebytesize", new Variant("d", (double) info.get_size()));

                Application.get_default().os.search(search);
            } catch (Error e) {
                stderr.printf("OpenSubtitles backed: Failed to stat file, reason: %s", e.message);
            }
        }

        [GtkCallback]
        public void nameButton_clicked_cb() {
            VariantBuilder terms = new VariantBuilder(VariantType.ARRAY);

            terms.add("{sv}", "query", new Variant("s", nameEntry.text));
            terms.add("{sv}", "season", new Variant("s", seasonEntry.text));
            terms.add("{sv}", "episode", new Variant("s", episodeEntry.text));

            Application.get_default().os.search(terms);
        }

        [GtkCallback]
        public void hashSizeButton_clicked_cb() {
            if (Application.get_default().current_file == null)
                return;

            try {
                FileInfo info = Application.get_default().current_file.query_info("*", FileQueryInfoFlags.NONE);

                VariantBuilder search = new VariantBuilder(VariantType.ARRAY);

                search.add("{sv}", "moviehash", new Variant("s", Utils.calculate_hash_for_file(Application.get_default().current_file)));
                search.add("{sv}", "moviebytesize", new Variant("d", (double) info.get_size()));

                Application.get_default().os.search(search);
            } catch (Error e) {
                stderr.printf("OpenSubtitles backed: Failed to stat file, reason: %s", e.message);
            }
        }

        [GtkCallback]
        public void subtitlesTree_row_activated_cb() {
            downloadButton_clicked_cb();
        }
    }
}
