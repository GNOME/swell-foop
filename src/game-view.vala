/*
 * This file is part of Swell-Foop.
 *
 * Copyright (C) 2010-2013 Robert Ancell
 * Copyright (C) 2023 Ben Corby
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

/*
 * Coding style.
 *
 * To help you comply with the coding style in this project use the
 * following greps. Any lines returned should be adjusted so they
 * don't match. The convoluted regular expressions are so they don't 
 * match them self.
 *
 * grep -ne '[^][)(_!$ "](' *.vala
 * grep -ne '[(] ' *.vala
 * grep -ne '[ ])' *.vala
 *
 */

using Config;
using Cairo; /* designed for Cairo */
using Gtk; /* designed for Gtk 4, link with libgtk-4-dev or gtk4-devel */

private class GameView : DrawingArea
{
    const int score_shown_for = 240;
    /* sub-classes */
    internal class Animation : Object
    {
        internal DateTime start_time;
        public enum eType {APPEAR, DESTROY, MOVE, SELECT}
        public eType animation_type;
        internal uint8 x;
        internal uint8 y;
        internal uint8 dx;
        internal uint8 dy;
        internal uint8 block_type;
        internal Tile tile;

        /* Constructor */
        internal Animation (eType type, uint8 x, uint8 y, uint8 block_type, uint8 dx = 0xff, uint8 dy = 0xff, Tile? t = null)
        {
            /* Object (animation_type: type, x: x, y: y, block_type: block_type, dx: dx, dy: dy); */
            animation_type = type;
            this.x = x;
            this.y = y;
            this.block_type = block_type;
            this.dx = dx;
            this.dy = dy;
            if (null != t)
                tile = t;
            start_time = new DateTime.now_utc ();
        }
    
        internal bool less_than (Animation source)
        {
            if (y > source.y)
                return true;
            else if (y == source.y && x < source.x)
                return true;
            else
                return false;
        }
    }

    private class OrderedList : Gee.ArrayList <Animation>
    {
        internal new bool add (Animation a)
        {
            int i;
            for (i = 0; i < size && !a.less_than (@get (i)); i++);
            insert (i, a);
            return true;
        }

        internal bool contain_only (Animation.eType t)
        {
            for (int i = 0; i < size; i++)
            {
                if (@get (i).animation_type != t)
                    return false;
            }
            return true;
        }

        internal void remove_type (Animation.eType t)
        {
            for (int i = size; i > 0; --i)
            {
                if (@get (i - 1).animation_type == t)
                    remove_at (i - 1);
            }
        }
    }

    /* member variables */
    OrderedList animations = new OrderedList ();
    private Game? game;

    string theme;

    bool game_complete = false;
    bool draw_highlight = false;

    DateTime animate_score_delta;
    uint score_delta = 0;

    /* context variables */
    int width;
    int height;
    uint x_offset;
    uint y_offset;
    uint x_delta;
    uint y_delta;
    bool first_draw = true;

    /* mouse variables */
    uint16 mouse_segment = 0xffff;
    bool mouse_pressed = false;
    uint x_cursor = -1;
    uint y_cursor = -1;

    /* frozen board variables */
    bool frozen_board_initialized = false;
    uint8 [,] frozen_board;
    bool frozen = false;
    int animation_length;
    private bool _animated = false;
    public bool animated {
        get { return _animated; }
        set { _animated= value; animation_length = _animated ? 240 : 5;}
    }

    Gee.Map<string, Rsvg.Handle> preloaded_svg = new Gee.HashMap<string, Rsvg.Handle> ();

    internal bool keypress (uint keyval, uint keycode)
    {
        switch (keyval)
        {
            case Gdk.Key.Up:
            case Gdk.Key.W: // added key for left hand use
            case Gdk.Key.w: // added key for left hand use
                cursor_move (0, 1);
                return true;
            case Gdk.Key.Down:
            case Gdk.Key.S: // added key for left hand use
            case Gdk.Key.s: // added key for left hand use
                cursor_move (0, -1);
                return true;
            case Gdk.Key.Left:
            case Gdk.Key.A: // added key for left hand use
            case Gdk.Key.a: // added key for left hand use
                cursor_move (-1, 0);
                return true;
            case Gdk.Key.Right:
            case Gdk.Key.D: // added key for left hand use
            case Gdk.Key.d: // added key for left hand use
                cursor_move (1, 0);
                return true;
            case Gdk.Key.space:
            case Gdk.Key.Return:
                cursor_click ();
                return true;
            default:
                return false;
        }
    }

    construct
    {
        set_hexpand (true);
        set_vexpand (true);
        focusable = true;
        set_draw_func ((/*DrawingArea*/ area, /*Cairo.Context*/ c, width, height)=>
        {
            if (!is_uninitialized () && !(frozen && !frozen_board_initialized))
            {
                var now = new DateTime.now_utc ();
                int animation_index = 0;
                Animation[] moves_to_do = {};
                if (first_draw)
                {
                    first_draw = false;
                    animations.clear ();
                    for (int y = game.rows - 1; y >= 0; --y)
                        for (int x = 0; x < game.columns; ++x)
                            if (null != game.current_board[y, x] && !game.current_board[y, x].closed)
                                animations.add (new Animation (APPEAR, (uint8)x, (uint8)y, game.current_board[y, x].color));
                }
                for (int y = game.rows - 1; y >= 0; --y)
                {
                    for (int x = 0; x < game.columns; ++x)
                    {
                        if (frozen)
                            draw_block (c, x_offset + x_delta * x, y_offset + y_delta * (game.rows - 1 - y), x_delta, y_delta, frozen_board[x, y], theme);
                        else if (animations.size > animation_index && x == animations.@get (animation_index).x && y == animations.@get (animation_index).y)
                        {
                            for (;animations.size > animation_index && 
                                x == animations.@get (animation_index).x && y == animations.@get (animation_index).y;)
                            {
                                if (animations.@get (animation_index).animation_type != MOVE) /* MOVE happens last */
                                {
                                    if (do_animation (c, animations.@get (animation_index), now))
                                        ++animation_index;
                                    else
                                        animations.remove_at (animation_index);
                                }
                                else
                                {
                                    moves_to_do += animations.@get (animation_index);
                                    ++animation_index;
                                }
                            }
                        }
                        else if (null != game.current_board[y, x] && !game.current_board[y, x].closed)
                        {
                            draw_block (c, x_offset + x_delta * x, y_offset + y_delta * (game.rows - 1 - y), x_delta, y_delta, game.current_board[y, x].color, theme);
                        }
                    }
                }
                for (int i = 0; i < moves_to_do.length; ++i)
                {
                    if (!do_animation (c, moves_to_do[i], now))
                        animations.remove (moves_to_do[i]);
                }
                if (draw_highlight)
                {
                    draw_cursor (c, x_offset + x_delta * x_cursor, y_offset + y_delta * (game.rows - 1 - y_cursor), x_delta, y_delta, theme);
                }
                if (animate_score (c, now, width, height) || animations.size > 0)
                {
#if GLIB_2_78_or_above
                    Timeout.add_once (3, redraw); /* The documentation says this requires glib 2.74, I couldn't compile it with 2.74 but could with 2.78. */
#else
                    Timeout.add (3, (()=>{redraw (); return false;}));
#endif
                }
            }
        });

        resize.connect((width, height) => {
            this.width = width;
            this.height = height;
            x_delta = width / game.columns;
            y_delta = height / game.rows;
            x_offset = (width - x_delta * game.columns) / 2;
            y_offset = (height - y_delta * game.rows) / 2;
            preloaded_svg.clear ();
		});
        var mouse_position = new EventControllerMotion ();
        mouse_position.motion.connect ((x,y)=> 
        {
            new_position ((int)x, (int)y);
        });
        mouse_position.enter.connect ((x,y)=>
        {
            new_position ((int)x, (int)y);
        });
        mouse_position.leave.connect (()=>
        {
            new_position (-1, -1);
        });

        var key_controller = new EventControllerKey ();
        var mouse_click = new EventControllerLegacy ();
        key_controller.key_pressed.connect ((controller,keyval,keycode,state)=>{ keypress(keyval, keycode);} );
        mouse_click.event.connect ((event)=>
        {
            switch (event.get_event_type ())
            {
                case Gdk.EventType.BUTTON_PRESS:
                    mouse_pressed = true;
                    redraw ();
                    return true;
                case Gdk.EventType.BUTTON_RELEASE:
                    mouse_pressed = false;
                    if (mouse_segment == 0xffff)
                        redraw ();
                    else
                        cursor_click (mouse_segment >> 8, (uint8)mouse_segment);
                    draw_highlight = false;
                    return true;
                default:
                    return false;
            }
        });
        add_controller (mouse_click);
        add_controller (key_controller);
        add_controller (mouse_position);
    }

    bool do_animation (Context c, Animation a, DateTime now)
    {
        /* to do, Consider adding sound to the animation.
         *
         * All the animations take 240ms.
         *
         * For any sound engineers out there who want to add sound to match the movement, the dropping blocks have five movements, each lasting 48 ms.
         * 1) an initial large drop
         * 2) an up bounce of 1/3 the initial drop height
         * 3) a second drop
         * 4) an up bounce of 1/6 the initial drop height
         * 5) final drop
         * (note: When undo is clicked this process is upside-down e.g an initial large rise, etc.)
         *
         * The block that get destroyed do so in the first 48ms of the 240ms.
         * The block that appear do so in the last 48ms of the 240ms.
         */
        int total_steps = animation_length;
        int segment_steps = animation_length / 5; /* 48 */
        var diff = now.difference (a.start_time);
        uint steps = (uint)(diff / (TimeSpan.MILLISECOND * 3));
        uint animation;
        if (steps >= total_steps - 1)
            animation = 0;
        else
            animation = (total_steps - 1 - steps);
        if (a.animation_type == MOVE)
        {
            uint range;
            uint p;
            if (animation >= total_steps - segment_steps /* 192 */)
            {
                range = segment_steps; /* 48 */
                p = total_steps - animation; /* 240 - (239 to 192) --> (1 to 48) */
            }
            else if (animation >= total_steps - segment_steps * 2 /* 144 */)
            {
                range = segment_steps * 3; /* 144 */
                p = animation - segment_steps; /* (191 to 144) - 48 --> (143 to 96)*/
            }
            else if (animation >= total_steps - segment_steps * 3 /* 96 */)
            {
                range = segment_steps * 3; /* 144 */
                p = total_steps - animation; /* 240 - (143 to 96) --> (97 to 144) */
            }
            else if (animation >= segment_steps /* 48 */)
            {
                range = segment_steps * 6; /* 288 */
                p = animation + segment_steps * 4; /* (95 to 48) + 144 --> (287 to 240) */
            }
            else
            {
                range = segment_steps * 6; /* 288 */
                p = segment_steps * 6 - animation;  /* (47 to 0) --> (241 to 288) */
            }
            draw_block (c,
                 (x_delta * ((long)a.x - a.dx))                                     * p / range + x_offset + x_delta * a.dx,
                 (y_delta * ((long)(game.rows - 1 - a.y) - (game.rows - 1 - a.dy))) * p / range + y_offset + y_delta * (game.rows - 1 - a.dy),
                 x_delta, y_delta, a.block_type, theme);
            return animation > 0;
        }
        else if (a.animation_type == DESTROY) 
        {
            if (animation >= total_steps - segment_steps)
            {
                var p = total_steps - animation; /* 0 to 47 */
                draw_block (c, x_offset + x_delta * a.x + x_delta * p / (segment_steps * 2),
                               y_offset + y_delta * (game.rows - 1 - a.y) + y_delta * p / (segment_steps * 2),
                               x_delta * (segment_steps - p) / segment_steps, y_delta * (segment_steps - p) / segment_steps, a.block_type, theme);
            }
            return animation >= total_steps - segment_steps;
        }
        else if (a.animation_type == APPEAR) 
        {
            if (animation < segment_steps)
            {
                var p = animation; /* 47 to 0 */
                draw_block (c, x_offset + x_delta * a.x + x_delta * p / (segment_steps * 2),
                               y_offset + y_delta * (game.rows - 1 - a.y) + y_delta * p / (segment_steps * 2),
                               x_delta * (segment_steps - p) / segment_steps, y_delta * (segment_steps - p) / segment_steps, a.block_type, theme);
            }
            return animation > 0;
        }
        else if (a.animation_type == SELECT) 
        {
            double degrees = (int)(steps % 360) - 180;

            /* move the selected blocks in a circular motion */
            /* draw_block (c, x_offset + (long)x_delta * a.x + (x_delta / 20) + (x_delta / 50) + Math.sin (degrees / 180 * Math.PI) * (x_delta / 20),
                           y_offset + (long)y_delta * (game.rows - 1 - a.y) + (y_delta / 20) + (y_delta / 50) + Math.cos (degrees / 180 * Math.PI) * (y_delta / 20),
                           x_delta * 9 / 10, y_delta * 9 / 10, a.block_type, theme);*/


            /* wobble the selected blocks */
            if (_animated) {
                const double wobble_size = 1.0 / 25; // the smaller the value the smaller (and slower) the wobble
                draw_block (c, x_offset + (long)x_delta * a.x + (x_delta * wobble_size) + (x_delta / 50) + Math.sin (degrees / 180 * Math.PI) * (x_delta * wobble_size),
                               y_offset + (long)y_delta * (game.rows - 1 - a.y) + (y_delta * wobble_size) + (y_delta / 50),
                               (uint)(x_delta * (1 - wobble_size * 2)), (uint)(y_delta * (1 - wobble_size * 2)), a.block_type, theme);
            } else {
                /* a basic draw for the selected blocks, with no animation */
                draw_block (c, x_offset + (long)x_delta * a.x,
                               y_offset + (long)y_delta * (game.rows - 1 - a.y),
                               x_delta, y_delta, a.block_type, theme);

            }

            return true;
        }
        else
            return false;
    }

    bool animate_score (Context c, DateTime now, int width, int height)
    {
        if (score_delta > 0)
        {
            var diff = now.difference (animate_score_delta);
            uint steps = (uint)(diff / (TimeSpan.MILLISECOND * 3));
            if (steps < animation_length)
            {
                string text = "+" + score_delta.to_string ();
                draw_text_font_size (c, width / 2, (int)(height / 2 * (animation_length - steps) / (float)animation_length), text, (int)steps, (animation_length - steps) / (float)animation_length);
                return true;
            }
            else
                return false;
        }
        else
            return false;
    }

    void draw_text_font_size (Context C, int x, int y, string text, int font_size, double a)
    {
        int x_offset, y_offset, width, height;
        get_text_offsets (C, text, font_size, out x_offset, out y_offset, out width, out height);
        C.move_to (x - x_offset - width / 2, y - y_offset - height / 2); 
        C.set_source_rgba (1, 1, 1, a);
        var layout =  Pango.cairo_create_layout (C);
        Pango.FontDescription font;
        if (null == layout.get_font_description ())
            font = Pango.FontDescription.from_string ("Sans Bold 1pt");
        else
            font = layout.get_font_description ().copy ();
        font.set_size (Pango.SCALE * font_size);
        layout.set_font_description (font);
        layout.set_text (text, -1);
        Pango.cairo_update_layout (C, layout);
        Pango.cairo_show_layout (C, layout);
    }

    void get_text_offsets (Context C, string text, int font_size, out int x_offset, out int y_offset, out int width, out int height)
    {
        var layout =  Pango.cairo_create_layout (C);
        Pango.FontDescription font;
        if (null == layout.get_font_description ())
            font = Pango.FontDescription.from_string ("Sans Bold 1pt");
        else
            font = layout.get_font_description ().copy ();
        font.set_size (Pango.SCALE * font_size);
        layout.set_font_description (font);
        layout.set_text (text, -1);
        Pango.cairo_update_layout (C, layout);
        Pango.Rectangle a,b;
        layout.get_extents (out a, out b);
        x_offset = a.x / Pango.SCALE;
        y_offset = a.y / Pango.SCALE;
        width = a.width / Pango.SCALE;
        height = a.height / Pango.SCALE;
    }

    /*\
    * * proxy calls
    \*/

    internal void set_game (Game game)
    {
        this.game = game;
        game.update_score.connect ((/* int */ points) =>
        {
            if (points > 0)
            {
                animate_score_delta = new DateTime.now_utc ();
                score_delta = points;
                redraw ();
            }
        });

        game.complete.connect (() =>
        {
            game_complete = true;
            draw_highlight = false;
        });
        game.started.connect (() =>
        {
            game_complete = false;
        });
    }

    internal void set_theme_name (string theme_name)
    {
        if (theme_name == "colors")
            theme = "colors";
        else if (theme_name == "boringshapes")
            theme = "boringshapes";
        else
            theme = "shapesandcolors";
    }

    internal void cursor_move (int x, int y)
    {
        draw_highlight = true;
        if (!is_uninitialized () && !game_complete)
        {
            if (x_cursor == -1 || y_cursor == -1 || x_cursor > game.columns - 1 || y_cursor > game.rows - 1)
            {
                x_cursor = game.columns / 2;
                y_cursor = game.rows / 2;
                redraw ();
            }
            else
            {
                bool r = false;
                if (x_cursor > 0 && x == -1 || x_cursor < game.columns - 1 && x == +1)
                {
                    x_cursor += x;
                    r = true;
                }
                if (y_cursor > 0 && y == -1 || y_cursor < game.rows - 1 && y == +1)
                {
                    y_cursor += y;
                    r = true;
                }
                if (r)
                {
                    add_select_animations ((uint8)x_cursor, (uint8)y_cursor);
                }
            }
        }
    }

    internal void cursor_click (uint8 x = 0xff, uint8 y = 0xff)
    {
        if (!frozen && (animations.size == 0 || animations.contain_only (SELECT)))
        {
            animations.clear ();
            if (null != game)
            {
                if (x == 0xff && y == 0xff)
                {
                    if (y_cursor < game.current_board.length[0] && x_cursor < game.current_board.length[1] && null != game.current_board[y_cursor, x_cursor])
                        game.remove_connected_tiles (game.current_board[y_cursor, x_cursor]);
                }
                else
                {
                    if (y < game.current_board.length[0] && x < game.current_board.length[1] && null != game.current_board[y, x])
                        game.remove_connected_tiles (game.current_board[y, x]);
                }
            }
        }
    }

    internal void freeze ()
    {
        if (!is_uninitialized ())
        {
            frozen_board = new uint8 [game.columns, game.rows];
            for (int y = game.rows - 1; y >= 0; --y)
            {
                for (int x = 0; x < game.columns; ++x)
                {
                    frozen_board[x, y] = null != game.current_board[y, x] ? game.current_board[y, x].color : 0;
                }
            }
            frozen_board_initialized = true;
        }
        frozen = true;
    }

    internal void unfreeze ()
    {
        frozen = false;
        redraw (); /* draw the changes */
    }

    internal void close (uint8 grid_x, uint8 grid_y, uint8 block_type)
    {
        animations.add (new Animation (DESTROY, grid_x, grid_y, block_type));
    }

    internal void appear (uint8 grid_x, uint8 grid_y, uint8 block_type)
    {
        animations.add (new Animation (APPEAR, grid_x, grid_y, block_type));
    }

    internal void move (uint8 old_x, uint8 old_y, uint8 new_x, uint8 new_y, uint8 block_type, Tile t)
    {
        if (merge_moves (old_x, old_y, new_x, new_y, block_type, t))
            merge_moves2 (t);
        else
            animations.add (new Animation (MOVE, new_x, new_y, block_type, old_x, old_y, t));
    }

    /* redraw */
    public void redraw ()
    {
        queue_draw ();
    }

    /* private functions */

    bool is_uninitialized ()
    {
        return null == game || null == game.current_board ||
            game.current_board.length[0] != game.rows || 
            game.current_board.length[1] != game.columns;
    }

    bool merge_moves (uint8 old_x, uint8 old_y, uint8 new_x, uint8 new_y, uint8 block_type, Tile t)
    {
        for (int i=0; i<animations.size; ++i)
        {
            if (animations.@get (i).animation_type == MOVE && animations.@get (i).tile == t)
            {
                if (new_x == animations.@get (i).dx && new_y == animations.@get (i).dy)
                {
                    animations.@get (i).dx = old_x;
                    animations.@get (i).dy = old_y;
                    return true;
                }
                else if (old_x == animations.@get (i).x && old_y == animations.@get (i).y)
                {
                    animations.@get (i).x = new_x;
                    animations.@get (i).y = new_y;
                    if (i > 0 && !animations.@get (i - 1).less_than (animations.@get (i)))
                        animations.add (animations.remove_at (i));
                    else if (i < animations.size - 1 && !animations.@get (i).less_than (animations.@get (i + 1)))
                        animations.add (animations.remove_at (i));
                    return true;
                }
            }
        }
        return false;
    }

    void merge_moves2 (Tile t)
    {
        for (;;)
        {
            int i;
            for (i = 0; i < animations.size && animations.@get (i).tile != t; i++);
            if (i < animations.size)
            {
                bool done_merge = false;
                int o;
                for (o = i + 1; o < animations.size; o++)
                {
                    if (animations.@get (o).tile == t)
                    {
                        if (animations.@get (o).x == animations.@get (i).dx && animations.@get (o).y == animations.@get (i).dy)
                        {
                            animations.@get (i).dx = animations.@get (o).dx;
                            animations.@get (i).dy = animations.@get (o).dy;
                            animations.remove_at (o);
                            done_merge = true;
                            break;
                        }
                        else if (animations.@get (i).x == animations.@get (o).dx && animations.@get (i).y == animations.@get (o).dy)
                        {
                            animations.@get (o).dx = animations.@get (i).dx;
                            animations.@get (o).dy = animations.@get (i).dy;
                            animations.remove_at (i);
                            done_merge = true;
                            break;
                        }
                    }
                }
                if (!done_merge)
                    return;
            }
            else
                assert (false);
        }
    }

    void new_position (int x, int y)
    {
        uint16 new_segment = segment (x, y);
        if (new_segment != mouse_segment)
        {
            mouse_segment = new_segment;
            if (mouse_segment != 0xffff)
            {
                add_select_animations (mouse_segment >> 8, (uint8)mouse_segment);
            }
            else
                animations.remove_type (SELECT);
        }
    }

    void add_select_animations (uint8 x, uint8 y)
    {
        animations.remove_type (SELECT);
        if (null != game && y < game.current_board.length[0] && x < game.current_board.length[1] && null != game.current_board[y, x])
        {
            var tiles = game.connected_tiles (game.current_board[y, x]);
            foreach (var tile in tiles)
                animations.add (new Animation (SELECT, tile.grid_x, tile.grid_y, tile.color));
        }
        redraw ();
    }

    uint16 segment (int x, int y)
    {
        if (x < 0 || x >= width || y < 0 || y >= height)
            return 0xffff;
        else
            return ((uint16)((uint8)((x - x_offset) / x_delta)) << 8) | (uint8)(game.rows - 1 - (y - y_offset) / y_delta);
    }

    void render_svg (Cairo.Context c, double x, double y, uint width, uint height, string path) throws Error
    {
        Rsvg.Rectangle viewport = Rsvg.Rectangle ();
        viewport.x = x;
        viewport.y = y;
        viewport.width = width;
        viewport.height = height;
        Rsvg.Handle handle;
        if (!preloaded_svg.has_key (path)) {
            var bytes = resources_lookup_data (path, 0);
            var data = bytes.get_data ();
            handle = new Rsvg.Handle.from_data (data);
            preloaded_svg.set (path, handle);
        } else {
            handle = preloaded_svg.get (path);
        }
        handle.render_document (c, viewport);
    }

    string get_block_name (uint8 block_id)
    {
        switch (block_id)
        {
            case 1:
               return "blue";
            case 2:
               return "green";
            case 3:
               return "yellow";
            case 4:
               return "red";
            default:
               return "";
        }
    }

    void draw_block (Cairo.Context c, double x, double y, uint x_size, uint y_size, uint8 block_id, string theme)
    {
        string block_name = get_block_name (block_id);
        string name = "/org/gnome/SwellFoop/themes/%s/%s.svg".printf (theme, block_name);
        try
        {
            render_svg (c, x, y, x_size, y_size, name);
        }
        catch (Error e)
        {
        }
        
    }

    void draw_cursor (Cairo.Context c, double x, double y, uint x_size, uint y_size, string theme)
    {
        string name = "/org/gnome/SwellFoop/themes/%s/%s.svg".printf (theme, "highlight");
        try
        {
            render_svg (c, x, y, x_size, y_size, name);
        }
        catch (Error e)
        {
        }
    }

}
