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
    private SwellFoopWindow window;
    enum eTheme {COLORS, SHAPESANDCOLORS, BORINGSHAPES}
    eTheme theme;

    /* play again button variables */
    bool game_complete = false;
    double button_height;
    double button_width;
    double b0_x;
    double b0_y;

    /* score variables */
    uint score = 0;
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
    double mouse_x = -1;
    double mouse_y = -1;
    uint x_cursor = -1;
    uint y_cursor = -1;

    /* frozen board variables */
    bool frozen_board_initilised = false;
    uint8 [,] frozen_board;
    bool frozen = false;

    construct
    {
        set_hexpand (true);
        set_vexpand (true);
        focusable = true;

        set_draw_func ((/*DrawingArea*/ area, /*Cairo.Context*/ c, width, height)=>
        {
            this.width = width;
            this.height = height;
            if (!is_unitilised () && !(frozen && !frozen_board_initilised))
            {
                x_delta = width / game.columns;
                y_delta = height / game.rows;
                x_offset = (width - x_delta * game.columns) / 2;
                y_offset = (height - y_delta * game.rows) / 2;
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
                if (!game_complete)
                    draw_cursor (c, x_offset + x_delta * x_cursor, y_offset + y_delta * (game.rows - 1 - y_cursor), x_delta, y_delta);
                draw_score (c, x_offset + x_delta * (game.columns / 2 - 1), 0,
                             x_delta * ((game.columns % 2)==0?2:3), y_delta, score);
                if (animate_score (c, now, width, height) || animations.size > 0)
                {
#if GLIB_2_78_or_above
                    Timeout.add_once (1, redraw); /* The documentaion says this requires glib 2.74, I couldn't compile it with 2.74 but could with 2.78. */
#else
                    Timeout.add (1, (()=>{redraw (); return false;}));
#endif
                }
                else
                {
                    if (game_complete)
                        draw_game_over (c, score, width, height);
                }
            }
        });

        var mouse_position = new EventControllerMotion ();
        mouse_position.motion.connect ((x,y)=> 
        {
            if (game_complete)
            {
                mouse_x = x;
                mouse_y = y;
                redraw ();
            }
            else
                new_position ((int)x, (int)y);
        });
        mouse_position.enter.connect ((x,y)=>
        {
            if (game_complete)
            {
                mouse_x = x;
                mouse_y = y;
                redraw ();
            }
            else
                new_position ((int)x, (int)y);
        });
        mouse_position.leave.connect (()=>
        {
            if (game_complete)
            {
                mouse_x = -1;
                mouse_y = -1;
                redraw ();
            }
            else
                new_position (-1, -1);
        });

        var mouse_click = new EventControllerLegacy ();
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
                    if (game_complete)
                    {
                        if (mouse_x >= b0_x && mouse_x < b0_x + button_width &&
                            mouse_y >= b0_y && mouse_y < b0_y + button_height)
                        {
                            game_complete = false;
                            window.activate_action ("new-game", null);
                        }
                    }
                    else
                    {
                        if (mouse_segment == 0xffff)
                            redraw ();
                        else
                            cursor_click (mouse_segment >> 8, (uint8)mouse_segment);
                    }
                    return true;
                default:
                    return false;
            }
        });
        add_controller (mouse_click);
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
        const int total_steps = 240;
        const int segment_steps = 240 / 5; /* 48 */
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

            /* to do for Robert, change selected block look */

            /* move the selected blocks in a circular motion */
            draw_block (c, x_offset + (long)x_delta * a.x + (x_delta / 20) + (x_delta / 50) + Math.sin (degrees / 180 * Math.PI) * (x_delta / 20),
                           y_offset + (long)y_delta * (game.rows - 1 - a.y) + (y_delta / 20) + (y_delta / 50) + Math.cos (degrees / 180 * Math.PI) * (y_delta / 20),
                           x_delta * 9 / 10, y_delta * 9 / 10, a.block_type, theme);


            /* wobble the selected blocks */
            /* const double wobble_size = 1.0 / 40; // the smalled the value the smaller (and slower) the wobble
            draw_block (c, x_offset + (long)x_delta * a.x + (x_delta * wobble_size) + (x_delta / 50) + Math.sin (degrees / 180 * Math.PI) * (x_delta * wobble_size),
                           y_offset + (long)y_delta * (game.rows - 1 - a.y) + (y_delta * wobble_size) + (y_delta / 50),
                           (uint)(x_delta * (1 - wobble_size * 2)), (uint)(y_delta * (1 - wobble_size * 2)), a.block_type, theme); */

            /* a basic draw for the selected blocks, with no animation */
            /*draw_block (c, x_offset + (long)x_delta * a.x,
                           y_offset + (long)y_delta * (game.rows - 1 - a.y),
                           x_delta, y_delta, a.block_type, theme);*/


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
            if (steps < 240)
            {
                string text = "+" + score_delta.to_string ();
                draw_text_font_size (c, width / 2, height / 2, text, (int)steps, (240.0 - steps) / 240.0);
/*
                int target_font_size = 1;
                double text_width = 0;
                double text_height = 0;
                for (int font_size = 1;font_size < 200;font_size++)
                {
                    Context t = new Context (c.get_target ());
                    t.move_to (0, 0);
                    t.set_font_size (font_size);
                    Cairo.TextExtents extents;
                    t.text_extents (text, out extents);
                    if (extents.width > steps || extents.height > steps)
                        break;
                    else
                    {
                        target_font_size = font_size;
                        text_width = extents.width;
                        text_height = extents.height;
                    }
                }
                c.move_to (width / 2 - text_width / 2, height / 2 + text_height / 2);
                c.set_font_size (target_font_size);
                c.set_source_rgba (1, 1, 1, (double)(240 - steps) / 240);
                c.show_text (text);
*/              return true;
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
            score += points;
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
        });
    }

    internal void set_score (uint s)
    {
        score = s;
    }

    internal void set_window (SwellFoopWindow w)
    {
        window = w;
        game_complete = false;
        window.set_focus (this);
        redraw ();
    }

    internal void set_theme_name (string theme_name)
    {
        if (theme_name == "colors")
            theme = COLORS;
        else if (theme_name == "boringshapes")
            theme = BORINGSHAPES;
        else
            theme = SHAPESANDCOLORS;
    }

    internal void cursor_move (int x, int y)
    {
        if (!is_unitilised () && !game_complete)
        {
            if (x_cursor == -1 || y_cursor == -1 || x_cursor > game.columns - 1 || y_cursor > game.rows - 1)
            {
                x_cursor = game.columns / 2;
                y_cursor = game.rows / 2;
                redraw ();
                window.set_focus (this);
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
                    window.set_focus (this);
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

    internal bool keypress (uint keyval, uint keycode, out bool remove_handler)
    {
        remove_handler = false;
        return false;
    }

    internal void freeze ()
    {
        if (!is_unitilised ())
        {
            frozen_board = new uint8 [game.columns, game.rows];
            for (int y = game.rows - 1; y >= 0; --y)
            {
                for (int x = 0; x < game.columns; ++x)
                {
                    frozen_board[x, y] = null != game.current_board[y, x] ? game.current_board[y, x].color : 0;
                }
            }
            frozen_board_initilised = true;
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

    bool is_unitilised ()
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

    void draw_block (Cairo.Context c, double x, double y, uint x_size, uint y_size, uint8 block_id, eTheme theme)
    {
        double x_m = x_size;
        double y_m = y_size;
        Pattern pattern;
        switch (block_id)
        {
            case 1: /* blue circle */
                x_m /= 50;
                y_m /= 50;
                /* background */
                c.set_operator (OVER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (0.8, 0.8, 0.8, 1);
                }
                else
                {
                    pattern = new Pattern.radial (x + x_m * 20, y + y_m * -10, 0, x + x_m * 25, y + y_m * 0, (x_m + y_m) * 30);
                    pattern.add_color_stop_rgba (0,0.447059,0.623529,0.811765,1);
                    pattern.add_color_stop_rgba (0.667479,0.223529,0.431373,0.701961,1);
                    pattern.add_color_stop_rgba (1,0.447059,0.623529,0.811765,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.set_fill_rule (WINDING);
                c.fill ();//c.fill_preserve ();
                /* border */
                c.set_operator (OVER);
                c.set_line_width (1);
                c.set_miter_limit (4);
                c.set_line_cap (BUTT);
                c.set_line_join (MITER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (1, 1, 1, 1);
                }
                else
                {
                    pattern = new Pattern.linear (x + x_m * 10, y + y_m * 0, x + x_m * 25, y + y_m * 50);
                    pattern.add_color_stop_rgba (0,1,1,1,1);
                    pattern.add_color_stop_rgba (1,0.447059,0.623529,0.811765,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.stroke (); 
                /* grey circle */
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (2.444445 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.2,0.2,0.2,0.6);
                    else
                        pattern = new pattern.rgba (0.447059,0.623529,0.811765,0.6);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 39.5, y + y_m * 26);
                    c.curve_to (x + x_m * 39.5, y + y_m * 33.457031, x + x_m * 33.457031, y + y_m * 39.5, x + x_m * 26, y + y_m * 39.5);
                    c.curve_to (x + x_m * 18.542969, y + y_m * 39.5, x + x_m * 12.5, y + y_m * 33.457031, x + x_m * 12.5, y + y_m * 26);
                    c.curve_to (x + x_m * 12.5, y + y_m * 18.542969, x + x_m * 18.542969, y + y_m * 12.5, x + x_m * 26, y + y_m * 12.5);
                    c.curve_to (x + x_m * 33.457031, y + y_m * 12.5, x + x_m * 39.5, y + y_m * 18.542969, x + x_m * 39.5, y + y_m * 26);
                    c.close_path ();
                    c.move_to (x + x_m * 39.5, y + y_m * 26);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    c.stroke ();
                }
                /* black circle */
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (2.444446 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.1,0.1,0.1,1);
                    else
                        pattern = new pattern.rgba (0.203922,0.396078,0.643137,1);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 38.5, y + y_m * 25);
                    c.curve_to (x + x_m * 38.5, y + y_m * 32.457031, x + x_m * 32.457031, y + y_m * 38.5, x + x_m * 25, y + y_m * 38.5);
                    c.curve_to (x + x_m * 17.542969, y + y_m * 38.5, x + x_m * 11.5, y + y_m * 32.457031, x + x_m * 11.5, y + y_m * 25);
                    c.curve_to (x + x_m * 11.5, y + y_m * 17.542969, x + x_m * 17.542969, y + y_m * 11.5, x + x_m * 25, y + y_m * 11.5);
                    c.curve_to (x + x_m * 32.457031, y + y_m * 11.5, x + x_m * 38.5, y + y_m * 17.542969, x + x_m * 38.5, y + y_m * 25);
                    c.close_path ();
                    c.move_to (x + x_m * 38.5, y + y_m * 25);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    c.stroke (); 
                }
                break;
            case 2: /* green square */
                x_m /= 50;
                y_m /= 50;
                /* background */
                c.set_operator (OVER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (0.8, 0.8, 0.8, 1);
                }
                else
                {
                    pattern = new Pattern.radial (x + x_m * 20, y + y_m * -10, 0, x + x_m * 25, y + y_m * 0, (x_m + y_m) * 30);
                    pattern.add_color_stop_rgba (0,0.541176,0.886275,0.203922,1);
                    pattern.add_color_stop_rgba (0.667479,0.345098,0.678431,0.027451,1);
                    pattern.add_color_stop_rgba (1,0.541176,0.886275,0.203922,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.set_fill_rule (WINDING);
                c.fill ();//c.fill_preserve ();
                /* border */
                c.set_operator (OVER);
                c.set_line_width (1);
                c.set_miter_limit (4);
                c.set_line_cap (BUTT);
                c.set_line_join (MITER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (1, 1, 1, 1);
                }
                else
                {
                    pattern = new Pattern.linear (x + x_m * 10, y + y_m * 0, x + x_m * 25, y + y_m * 50);
                    pattern.add_color_stop_rgba (0,1,1,1,1);
                    pattern.add_color_stop_rgba (1,0.541176,0.886275,0.203922,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.stroke ();
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.2,0.2,0.2,0.6);
                    else
                        pattern = new pattern.rgba (0.541176,0.886275,0.203922,0.4);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 14.5, y + y_m * 14.5);
                    c.line_to (x + x_m * 37.5, y + y_m * 14.5);
                    c.line_to (x + x_m * 37.5, y + y_m * 37.5);
                    c.line_to (x + x_m * 14.5, y + y_m * 37.5);
                    c.close_path ();
                    c.move_to (x + x_m * 14.5, y + y_m * 14.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    if (theme == BORINGSHAPES)
                        c.fill ();
                    else
                        c.stroke ();
                }
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.1,0.1,0.1,1);
                    else
                        pattern = new pattern.rgba (0.345098,0.678431,0.027451,1);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 13.5, y + y_m * 13.5);
                    c.line_to (x + x_m * 36.5, y + y_m * 13.5);
                    c.line_to (x + x_m * 36.5, y + y_m * 36.5);
                    c.line_to (x + x_m * 13.5, y + y_m * 36.5);
                    c.close_path ();
                    c.move_to (x + x_m * 13.5, y + y_m * 13.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    c.stroke ();
                }
                break;
            case 3: /* yellow star */
                x_m /= 50;
                y_m /= 50;
                /* background */
                c.set_operator (OVER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (0.8, 0.8, 0.8, 1);
                }
                else
                {
                    pattern = new Pattern.radial (x + x_m * 20, y + y_m * -10, 0, x + x_m * 25, y + y_m * 0, (x_m + y_m) * 30);
                    pattern.add_color_stop_rgba (0,0.992157,0.941176,0.545098,1);
                    pattern.add_color_stop_rgba (0.667479,0.929412,0.831373,0,1);
                    pattern.add_color_stop_rgba (1,0.992157,0.941176,0.545098,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.set_fill_rule (WINDING);
                c.fill ();//c.fill_preserve ();
                /* border */
                c.set_operator (OVER);
                c.set_line_width (1);
                c.set_miter_limit (4);
                c.set_line_cap (BUTT);
                c.set_line_join (MITER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (1, 1, 1, 1);
                }
                else
                {
                    pattern = new Pattern.linear (x + x_m * 10, y + y_m * 0, x + x_m * 25, y + y_m * 50);
                    pattern.add_color_stop_rgba (0,1,1,1,1);
                    pattern.add_color_stop_rgba (1,0.988235,0.913725,0.309804,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.stroke ();
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3.104212 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.2,0.2,0.2,0.8);
                    else
                        pattern = new pattern.rgba (0.988235,0.913725,0.309804,1);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 26, y + y_m * 11.5);
                    c.line_to (x + x_m * 30.261719, y + y_m * 20.132813);
                    c.line_to (x + x_m * 39.789063, y + y_m * 21.515625);
                    c.line_to (x + x_m * 32.894531, y + y_m * 28.234375);
                    c.line_to (x + x_m * 34.523438, y + y_m * 37.722656);
                    c.line_to (x + x_m * 26, y + y_m * 33.242188);
                    c.line_to (x + x_m * 17.476563, y + y_m * 37.722656);
                    c.line_to (x + x_m * 19.105469, y + y_m * 28.234375);
                    c.line_to (x + x_m * 12.210938, y + y_m * 21.515625);
                    c.line_to (x + x_m * 21.738281, y + y_m * 20.132813);
                    c.close_path ();
                    c.move_to (x + x_m * 26, y + y_m * 11.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    if (theme == BORINGSHAPES)
                        c.fill ();
                    else
                        c.stroke ();
                }
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3.104212 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.1,0.1,0.1,1);
                    else
                        pattern = new pattern.rgba (0.92549,0.752941,0,1);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 25, y + y_m * 10.5);
                    c.line_to (x + x_m * 29.261719, y + y_m * 19.132813);
                    c.line_to (x + x_m * 38.789063, y + y_m * 20.515625);
                    c.line_to (x + x_m * 31.894531, y + y_m * 27.234375);
                    c.line_to (x + x_m * 33.523438, y + y_m * 36.722656);
                    c.line_to (x + x_m * 25, y + y_m * 32.242188);
                    c.line_to (x + x_m * 16.476563, y + y_m * 36.722656);
                    c.line_to (x + x_m * 18.105469, y + y_m * 27.234375);
                    c.line_to (x + x_m * 11.210938, y + y_m * 20.515625);
                    c.line_to (x + x_m * 20.738281, y + y_m * 19.132813);
                    c.close_path ();
                    c.move_to (x + x_m * 25, y + y_m * 10.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    c.stroke ();
                }
                break;
            case 4: /* red triangle */
                x_m /= 50;
                y_m /= 50;
                /* background */
                c.set_operator (OVER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (0.8, 0.8, 0.8, 1);
                }
                else
                {
                    pattern = new Pattern.radial (x + x_m * 20, y + y_m * -10, 0, x + x_m * 25, y + y_m * 0, (x_m + y_m) * 30);
                    pattern.add_color_stop_rgba (0,0.937255,0.160784,0.160784,1);
                    pattern.add_color_stop_rgba (0.667479,0.721569,0,0,1);
                    pattern.add_color_stop_rgba (1,0.937255,0.160784,0.160784,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.set_fill_rule (WINDING);
                c.fill ();//c.fill_preserve ();
                /* border */
                c.set_operator (OVER);
                c.set_line_width (1);
                c.set_miter_limit (4);
                c.set_line_cap (BUTT);
                c.set_line_join (MITER);
                if (theme == BORINGSHAPES)
                {
                    c.set_source_rgba (1, 1, 1, 1);
                }
                else
                {
                    pattern = new Pattern.linear (x + x_m * 10, y + y_m * 0, x + x_m * 25, y + y_m * 50);
                    pattern.add_color_stop_rgba (0,0.937255,0.160784,0.160784,1);
                    pattern.add_color_stop_rgba (1,0.988235,0.686275,0.243137,1);
                    pattern.set_extend (PAD);
                    pattern.set_filter (GOOD);
                    c.set_source (pattern);
                }
                c.new_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.line_to (x + x_m * 45.335938, y + y_m * 1.5);
                c.curve_to (x + x_m * 47.082031, y + y_m * 1.5, x + x_m * 48.5, y + y_m * 2.917969, x + x_m * 48.5, y + y_m * 4.664063);
                c.line_to (x + x_m * 48.5, y + y_m * 45.335938);
                c.curve_to (x + x_m * 48.5, y + y_m * 47.082031, x + x_m * 47.082031, y + y_m * 48.5, x + x_m * 45.335938, y + y_m * 48.5);
                c.line_to (x + x_m * 4.664063, y + y_m * 48.5);
                c.curve_to (x + x_m * 2.917969, y + y_m * 48.5, x + x_m * 1.5, y + y_m * 47.082031, x + x_m * 1.5, y + y_m * 45.335938);
                c.line_to (x + x_m * 1.5, y + y_m * 4.664063);
                c.curve_to (x + x_m * 1.5, y + y_m * 2.917969, x + x_m * 2.917969, y + y_m * 1.5, x + x_m * 4.664063, y + y_m * 1.5);
                c.close_path ();
                c.move_to (x + x_m * 4.664063, y + y_m * 1.5);
                c.set_tolerance (0.1);
                c.set_antialias (DEFAULT);
                c.stroke ();
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3.371869 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.2,0.2,0.2,0.2);
                    else
                        pattern = new pattern.rgba (0.937255,0.160784,0.160784,0.501961);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 40.832031, y + y_m * 36.5);
                    c.line_to (x + x_m * 11.167969, y + y_m * 36.5);
                    c.line_to (x + x_m * 18.582031, y + y_m * 23.675781);
                    c.line_to (x + x_m * 26, y + y_m * 10.847656);
                    c.line_to (x + x_m * 33.417969, y + y_m * 23.675781);
                    c.close_path ();
                    c.move_to (x + x_m * 40.832031, y + y_m * 36.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    if (theme == BORINGSHAPES)
                        c.fill ();
                    else
                        c.stroke ();
                }
                /********************/
                if (theme != COLORS)
                {
                    c.set_operator (OVER);
                    c.set_line_width (3.371869 * ((x_m + y_m) / 2));
                    c.set_miter_limit (4);
                    c.set_line_cap (BUTT);
                    c.set_line_join (MITER);
                    if (theme == BORINGSHAPES)
                        pattern = new pattern.rgba (0.1,0.1,0.1,1);
                    else
                        pattern = new pattern.rgba (0.721569,0,0,1);
                    c.set_source (pattern);
                    c.new_path ();
                    c.move_to (x + x_m * 39.832031, y + y_m * 35.5);
                    c.line_to (x + x_m * 10.167969, y + y_m * 35.5);
                    c.line_to (x + x_m * 17.582031, y + y_m * 22.675781);
                    c.line_to (x + x_m * 25, y + y_m * 9.847656);
                    c.line_to (x + x_m * 32.417969, y + y_m * 22.675781);
                    c.close_path ();
                    c.move_to (x + x_m * 39.832031, y + y_m * 35.5);
                    c.set_tolerance (0.1);
                    c.set_antialias (DEFAULT);
                    c.stroke ();
                }
                break;
            default:
                break;
        }
    }

    void draw_cursor (Cairo.Context c, double x, double y, uint x_size, uint y_size)
    {
        /* to do, fix the cursor as it isn't very clear on the yellow block */
        Pattern pattern = new Pattern.radial (x + x_size * 0.5, y + y_size * 0.5, 0, x + x_size * 0.5, y + y_size * 0.5, (x_size + y_size) / 8);
        if (theme == BORINGSHAPES) /* to do, this is an attempt to make the cursor clearer when on the BORINGSHAPES circle, it could be improved */
            pattern.add_color_stop_rgba (0,1,1,1,1);
        else
            pattern.add_color_stop_rgba (0,1,1,1,0.75);
        pattern.add_color_stop_rgba (0.75,1,1,1,0);
        pattern.add_color_stop_rgba (1,1,1,1,0);
        c.set_source (pattern);
        c.move_to (x + x_size * 0.5,  y);
        c.curve_to (x + x_size * 0.5, y,
                    x + x_size * 1,   y,
                    x + x_size * 1,   y + y_size * 0.5);
        c.curve_to (x + x_size * 1,   y + y_size * 0.5,
                    x + x_size * 1,   y + y_size * 1,
                    x + x_size * 0.5, y + y_size * 1);
        c.curve_to (x + x_size * 0.5, y + y_size * 1,
                    x + x_size * 0,   y + y_size * 1,
                    x + x_size * 0,   y + y_size * 0.5);
        c.curve_to (x + x_size * 0,   y + y_size * 0.5,
                    x + x_size * 0,   y + y_size * 0,
                    x + x_size * 0.5, y);
        c.fill ();
    }

    void draw_score (Context C, double x, double y, double width, double height, uint score, bool bright = false)
    {
        string text = score.to_string ();
        for (;text.length < 5;text = "0" + text);
        int x_offset, y_offset;
        double text_width, text_height;
        int target_font_size = calculate_font_size_from_max (C, text, (int)width, (int)height, 
            out text_width, out text_height, out x_offset, out y_offset);

        /* draw */
        C.move_to (x - x_offset + (width - text_width) / 2, y - y_offset + (height - text_height) / 2); 
        if (bright)
            C.set_source_rgb (1.0, 1.0, 1.0);
        else
            C.set_source_rgb (0.5, 0.5, 0.5);
        var layout =  Pango.cairo_create_layout (C);
        Pango.FontDescription font;
        if (null == layout.get_font_description ())
            font = Pango.FontDescription.from_string ("Sans Bold 1pt");
        else
            font = layout.get_font_description ().copy ();
        font.set_size (Pango.SCALE * target_font_size);
        layout.set_font_description (font);
        layout.set_text (text, -1);
        Pango.cairo_update_layout (C, layout);
        Pango.cairo_show_layout (C, layout);
    }

    void draw_game_over (Context c, uint score, double context_width, double context_height)
    {
        const double PI2 = 1.570796326794896619231321691639751442; /* PI divided by 2 */
        const double border_width = 5;

        /* write the score brighter */
        draw_score (c, x_offset + x_delta * (game.columns / 2 - 1), 0,
                                x_delta * ((game.columns % 2)==0?2:3), y_delta, score, true);

        /* Translators: message displayed to show the game has finished */
        string text = _("Game Over!");
        double game_over_width, game_over_height;
        int game_over_x_offset, game_over_y_offset;
        int font_size = calculate_font_size_from_max (c, text, (int)width, (int)y_delta,
             out game_over_width, out game_over_height, out game_over_x_offset, out game_over_y_offset);
        draw_dialogue_text (c, (context_width - game_over_width) / 2, y_delta + (y_delta - game_over_height) / 2, text, font_size, game_over_x_offset, game_over_y_offset, true);
        
        /* draw buttons */
        /* to do for Robert, adjust button size */
        button_height = game_over_height * 2;
        button_width = game_over_width;
        /* max size for button */
        button_height = button_height > 150 ? 150 : button_height; /* maximum height 150 */
        button_width = button_width > 350 ? 350 : button_width;    /* maximum width 350 */
        /* button position */
        b0_x = (context_width - button_width) / 2;
        b0_y = 2.5 * y_delta;
        if (b0_y + button_height > context_height)
            b0_y = context_height - button_height;
        /* draw button */
        double b0_radius = button_width < button_height ? button_width / 3 : button_height / 3;
        c.move_to (b0_x + button_width, b0_y);
        c.arc (b0_x + button_width - b0_radius, b0_y + b0_radius, b0_radius, -PI2, 0);
        c.arc (b0_x + button_width - b0_radius, b0_y + button_height - b0_radius, b0_radius, 0, PI2);
        c.arc (b0_x + b0_radius, b0_y + button_height - b0_radius, b0_radius, PI2, PI2 * 2);
        c.arc (b0_x + b0_radius, b0_y + b0_radius, b0_radius, PI2 * 2, -PI2);
        c.set_source_rgba (0.8, 0.8, 0.8, 1); /* border color */
        c.fill ();                
        c.arc (b0_x + button_width - b0_radius, b0_y + b0_radius, b0_radius- border_width, -PI2, 0);
        c.arc (b0_x + button_width - b0_radius, b0_y + button_height - b0_radius, b0_radius- border_width, 0, PI2);
        c.arc (b0_x + b0_radius, b0_y + button_height - b0_radius, b0_radius - border_width, PI2, PI2 * 2);
        c.arc (b0_x + b0_radius, b0_y + b0_radius, b0_radius - border_width, PI2 * 2, -PI2);
        if (mouse_pressed && mouse_x >= b0_x && mouse_x < b0_x + button_width && mouse_y >= b0_y && mouse_y < b0_y + button_height)
            c.set_source_rgba (0, 0, 0, 1); /* background color when the button is depressed */
        else
            c.set_source_rgba (0.15, 0.15, 0.15, 1); /* background color when the button is raised */
        c.fill ();
        /* Translators: message displayed in a Button if the player wants to play the game again */
        text = _("Play Again?");
        /* draw text */
        double b0_width, b0_height;
        int x_offset, y_offset;
        font_size = calculate_font_size_from_max (c, text, (int)(button_width - border_width * 3), (int)(button_height / 2) , out b0_width, out b0_height, out x_offset, out y_offset);
        draw_dialogue_text (c, b0_x + (button_width - b0_width) / 2 , b0_y + /*b0_height +*/ button_height / 3, text, font_size, x_offset, y_offset);
    }

    void draw_dialogue_text (Context C, double x, double y, string text, int font_size, int x_offset, int y_offset, bool bright = false)
    {
        /* draw using x,y as the top left corner of the text */
        C.move_to (x - x_offset, y - y_offset); 
        if (bright)
            C.set_source_rgb (1.0, 1.0, 1.0);
        else
            C.set_source_rgb (0.75, 0.75, 0.75);
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

    int calculate_font_size_from_max (Context C, string text, int max_width, int max_height,
                                      out double width, out double height, out int x_offset, out int y_offset)
    {
        int target_font_size = 1;
        width = 0;
        height = 0;
        x_offset = 0;
        y_offset = 0;
        for (int font_size = 1;font_size < 200;)
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
            if (a.width / Pango.SCALE < max_width && a.height / Pango.SCALE < max_height)
            {
                width = a.width / Pango.SCALE;
                height = a.height / Pango.SCALE;
                target_font_size = font_size;
                x_offset = a.x / Pango.SCALE;
                y_offset = a.y / Pango.SCALE;
            }
            else
                break;
            if (font_size < 20)
                font_size++;
            else if (font_size < 50)
                font_size+=5;
            else
                font_size+=10;
        }
        return target_font_size;
    }
}
