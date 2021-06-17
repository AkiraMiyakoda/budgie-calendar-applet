/*
 * This file is part of calendar-applet
 *
 * Copyright (C) 2017-2018 Daniel Pinto <danielpinto8zz6@gmail.com>
 * Copyright (C) 2014-2016 Ikey Doherty <ikey@solus-project.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

namespace CalendarApplet {
    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget (string uuid) {
            return new Applet ();
        }
    }

    enum ClockFormat {
        TWENTYFOUR = 0,
        TWELVE = 1;
    }

    public const string CALENDAR_MIME = "text/calendar";

    public class Applet : Budgie.Applet {
        protected Gtk.EventBox widget;
        protected Gtk.Box layout;
        protected Gtk.Label clock;
        protected Gtk.Label date_label;
        protected Gtk.Label seconds_label;

        protected bool ampm = false;
        protected bool show_seconds = false;
        protected bool show_date = false;

        protected bool show_custom_format = false;
        protected string ? custom_format = null;

        protected bool show_custom_header = false;
        protected string ? custom_header_1 = null;
        protected string ? custom_header_2 = null;
        protected int header_alignment = 0;

        private DateTime time;

        protected Settings settings;
        protected Settings applet_settings;

        Budgie.Popover ? popover = null;

        Gtk.Orientation orient = Gtk.Orientation.HORIZONTAL;

        private unowned Budgie.PopoverManager ? manager = null;

        private Gtk.Label header_1;
        private Gtk.Label header_2;

        private Gtk.Calendar calendar;

        public override void panel_position_changed (Budgie.PanelPosition position) {
            if (position == Budgie.PanelPosition.LEFT || position == Budgie.PanelPosition.RIGHT) {
                this.orient = Gtk.Orientation.VERTICAL;
            } else {
                this.orient = Gtk.Orientation.HORIZONTAL;
            }
            this.seconds_label.set_text ("");
            this.layout.set_orientation (this.orient);
            this.update_clock ();
        }

        public Applet () {
            GLib.Intl.setlocale (GLib.LocaleCategory.ALL, "");
            GLib.Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALE_DIR);
            GLib.Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            GLib.Intl.textdomain (Config.GETTEXT_PACKAGE);

            widget = new Gtk.EventBox ();
            layout = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);

            clock = new Gtk.Label ("");
            time = new DateTime.now_local ();
            widget.add (layout);

            layout.pack_start (clock, false, false, 0);
            layout.margin = 0;
            layout.border_width = 0;

            seconds_label = new Gtk.Label ("");
            seconds_label.get_style_context ().add_class ("dim-label");
            layout.pack_start (seconds_label, false, false, 0);
            seconds_label.no_show_all = true;
            seconds_label.hide ();

            date_label = new Gtk.Label ("");
            layout.pack_start (date_label, false, false, 0);
            date_label.no_show_all = true;
            date_label.hide ();

            clock.valign = Gtk.Align.CENTER;
            seconds_label.valign = Gtk.Align.CENTER;
            date_label.valign = Gtk.Align.CENTER;

            settings = new Settings ("org.gnome.desktop.interface");
            applet_settings = new Settings ("com.github.danielpinto8zz6.budgie-calendar-applet");

            get_style_context ().add_class ("budgie-clock-applet");

            // Create a submenu system
            popover = new Budgie.Popover (widget);

            header_1 = new Gtk.Label ("");
            header_1.get_style_context ().add_class ("h1");
            header_1.set_halign (Gtk.Align.START);
            header_1.margin_bottom = 6;
            header_1.margin_start = 6;

            header_2 = new Gtk.Label ("");
            header_2.get_style_context ().add_class ("h2");
            header_2.set_halign (Gtk.Align.START);
            header_2.margin_start = 6;
            header_2.margin_bottom = 12;

            calendar = new Gtk.Calendar ();

            var main_grid = new Gtk.Grid ();
            main_grid.orientation = Gtk.Orientation.VERTICAL;
            main_grid.margin = 6;
            main_grid.get_style_context ().add_class ("budgie-calendar-applet");

            main_grid.add (header_1);
            main_grid.add (header_2);
            main_grid.add (calendar);

            popover.add (main_grid);

            widget.button_press_event.connect ((e)=> {
                if (e.button != 1) {
                    return Gdk.EVENT_PROPAGATE;
                }
                if (popover.get_visible ()) {
                    popover.hide ();
                } else {
                    update_headers ();
                    calendar.day = time.get_day_of_month ();
                    calendar.month = time.get_month () - 1;
                    calendar.year = time.get_year ();
                    this.manager.show_popover (widget);
                }
                return Gdk.EVENT_STOP;
            });

            Timeout.add_seconds_full (GLib.Priority.LOW, 1, update_clock);

            settings.bind ("clock-show-date",    date_label,    "visible", SettingsBindFlags.DEFAULT);
            settings.bind ("clock-show-seconds", seconds_label, "visible", SettingsBindFlags.DEFAULT);

            settings.changed.connect (on_settings_change);
            applet_settings.changed.connect (on_settings_change);

            update_clock ();
            update_headers ();
            add (widget);

            on_settings_change ("clock-format");
            on_settings_change ("clock-show-seconds");
            on_settings_change ("clock-show-date");
            on_settings_change ("show-custom-format");
            on_settings_change ("custom-format");
            on_settings_change ("show-custom-header");
            on_settings_change ("custom-header-1");
            on_settings_change ("custom-header-2");
            on_settings_change ("header-alignment");
            on_settings_change ("calendar-show-week-numbers");

            popover.get_child ().show_all ();

            show_all ();
        }

        public override void update_popovers (Budgie.PopoverManager ? manager) {
            this.manager = manager;
            manager.register_popover (widget, popover);
        }

        protected void on_settings_change (string key) {
            switch (key) {
            case "clock-format" :
                ClockFormat f = (ClockFormat)settings.get_enum (key);
                ampm = f == ClockFormat.TWELVE;
                this.update_clock ();
                break;
            case "clock-show-seconds" :
                show_seconds = settings.get_boolean (key);
                this.update_clock ();
                break;
            case "clock-show-date" :
                show_date = settings.get_boolean (key);
                this.update_clock ();
                break;
            case "show-custom-format" :
                show_custom_format = applet_settings.get_boolean (key);
                if (show_custom_format) {
                    settings.set_boolean ("clock-show-seconds", false);
                    settings.set_boolean ("clock-show-date",    false);
                }
                this.update_clock ();
                break;
            case "custom-format" :
                custom_format = applet_settings.get_string (key);
                this.update_clock ();
                break;
            case "show-custom-header" :
                show_custom_header = applet_settings.get_boolean (key);
                this.update_headers ();
                break;
            case "custom-header-1" :
                custom_header_1 = applet_settings.get_string (key);
                this.update_headers ();
                break;
            case "custom-header-2" :
                custom_header_2 = applet_settings.get_string (key);
                this.update_headers ();
                break;
            case "header-alignment" :
                header_alignment = applet_settings.get_int (key);
                this.update_headers ();
                break;
            case "calendar-show-week-numbers" :
                calendar.show_week_numbers = applet_settings.get_boolean ("calendar-show-week-numbers");
                break;
            }
        }


        /**
         * Update the date if necessary
         */
        protected void update_date () {
            if (!show_date) {
                return;
            }
            string ftime;
            if (this.orient == Gtk.Orientation.HORIZONTAL) {
                ftime = "%x";
            } else {
                ftime = "<small>%b %d</small>";
            }

            // Prevent unnecessary redraws
            var old = date_label.get_label ();
            var ctime = time.format (ftime);
            if (old == ctime) {
                return;
            }

            date_label.set_markup (ctime);
        }

        /**
         * Update the seconds if necessary
         */
        protected void update_seconds () {
            if (!show_seconds) {
                return;
            }
            string ftime;
            if (this.orient == Gtk.Orientation.HORIZONTAL) {
                ftime = "";
            } else {
                ftime = "<big>%S</big>";
            }

            // Prevent unnecessary redraws
            var old = date_label.get_label ();
            var ctime = time.format (ftime);
            if (old == ctime) {
                return;
            }

            seconds_label.set_markup (ctime);
        }

        /**
         * This is called once every second, updating the time
         */
        protected bool update_clock () {
            time = new DateTime.now_local ();
            string format;

            if (show_custom_format) {
                format = custom_format;
            } else if (ampm) {
                format = "%l:%M";
                if (orient == Gtk.Orientation.HORIZONTAL) {
                    if (show_seconds) {
                        format += ":%S";
                    }
                }
                format += " %p";
            } else {
                format = "%H:%M";
                if (orient == Gtk.Orientation.HORIZONTAL) {
                    if (show_seconds) {
                    format += ":%S";
                    }
                }
            }

            string ftime;
            if (this.orient == Gtk.Orientation.HORIZONTAL) {
                ftime = " %s ".printf (format);
            } else {
                ftime = " <small>%s</small> ".printf (format);
            }

            if (!show_custom_format) {
                this.update_date ();
                this.update_seconds ();
            }

            // Prevent unnecessary redraws
            var old = clock.get_label ();
            var ctime = time.format (ftime);
            if (old == ctime) {
                return true;
            }

            clock.set_markup (ctime);
            this.queue_draw ();

            return true;
        }

        public void update_headers () {
            var time = new DateTime.now_local ();

            string label1 = "";
            string label2 = "";

            if (show_custom_header) {
                label1 = time.format (custom_header_1);
                label2 = time.format (custom_header_2);
            }
            else {
                label1 = time.format ("%A");
                label1 = label1.substring (0, 1).up () + label1.substring (1);
                label2 = time.format ("%e %B %Y");
            }

            if (label1 != "") {
                header_1.set_label (label1);
                header_1.show ();
            }
            else {
                header_1.hide ();
            }

            if (label2 != "") {
                header_2.set_label (label2);
                header_2.show ();
            }
            else {
                header_2.hide ();
            }

            Gtk.Align align;
            switch (header_alignment) {
            case 1:
                align = Gtk.Align.FILL;
                break;
            case 2:
                align = Gtk.Align.END;
                break;
            default:
                align = Gtk.Align.START;
                break;
            }

            header_1.set_halign(align);
            header_2.set_halign(align);
        }

        public override bool supports_settings () {
            return true;
        }

        public override Gtk.Widget ? get_settings_ui () {
            return new CalendarApplet.AppletSettings ();
        }
    }
}

[ModuleInit]
public void peas_register_types (TypeModule module) {
    // boilerplate - all modules need this
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Budgie.Plugin), typeof (CalendarApplet.Plugin));
}