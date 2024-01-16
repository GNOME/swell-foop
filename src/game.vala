/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

/**
 *  This is the model layer of a tile.
 */
private class Tile : Object
{
    /* Property */
    private bool _closed = false;
    internal bool closed
    {
        internal get { return _closed; }
        private set
        {
            _closed = value;
            if (_closed)
                view.close (grid_x, grid_y, color);
        }
    }

    public uint8 grid_x   { internal get; protected construct set; }
    public uint8 grid_y   { internal get; protected construct set; }
    public uint8 color    { internal get; protected construct; }    /* 1 <= color <= 4 */
    // Vala tip or bug: looks like "private" means "accessible only from this file"; but if both get and set are private, there is a warning
    internal bool visited { protected get; private set; default = false; }

    GameView view;

    /* Constructor */
    internal Tile (GameView view, uint8 x, uint8 y, uint8 c)
    {
        Object (grid_x: x, grid_y: y, color: c);
        this.view = view;
        view.appear (x, y, c);
    }

    /* Do not use this mothod to initialize the position. */
    internal void update_position (uint8 new_x, uint8 new_y)
    {
        if (closed)
            return;

        uint8 old_x = grid_x;
        uint8 old_y = grid_y;

        if ((new_x != old_x) || (new_y != old_y))
        {
            grid_x = new_x;
            grid_y = new_y;

            if (!closed)
                view.move (old_x, old_y, new_x, new_y, color, this);
        }
    }
}

/**
 *  This is the model layer of the whole game. All game logic goes here. This class tries not to
 *  bring in any visual stuff to comply the separation of view-model idea.
 */
private class Game : Object
{
    internal Tile? [,] current_board;
    internal bool is_started { get; private set; default = false; }

    /* Game score */
    internal uint score { internal get; private set; default = 0; }

    private uint8 _color_num = 3;
    public uint8 color_num
    {
        internal get { return _color_num; }
        protected construct set     // TODO should be doable to make construct only again
        {
            if (value < 2 || value > 4)
                _color_num = 3;
            else
                _color_num = value;
        }
    }

    /* Property */
    public uint8 rows       { internal get; protected construct; }
    public uint8 columns    { internal get; protected construct; }
    private GameView view;

    internal signal void update_score (int points_awarded);
    internal signal void complete ();
    internal signal void started ();

    /* Constructor */
    internal Game (uint8 rows, uint8 columns, uint8 color_num, GameView view, Variant? saved_game)
    {
        Object (rows: rows, columns: columns, color_num: color_num);
        this.view = view;
        if (saved_game == null || !load_saved_game ((!) saved_game))
            create_new_game ();
    }

//    private static string to_string (ref Tile [,] current_board)
//    {
//        uint8 rows    = (uint8) current_board.length [0];
//        uint8 columns = (uint8) current_board.length [1];
//        string board  = "\n";
//        for (uint8 row = rows; row > 0; row--)
//        {
//            for (uint8 col = 0; col < columns; col++)
//                if (current_board [row - 1, col] == null)
//                    board += ". ";
//                else if (((!) current_board [row - 1, col]).closed)
//                    board += "0 ";
//                else
//                    board += ((!) current_board [row - 1, col]).color.to_string () + " ";
//            board += "\n";
//        }
//        return (board);
//    }

    private inline void create_new_game ()
    {
        initial_board = new uint8 [rows, columns];
        current_board = new Tile? [rows, columns];

        /* populate with the requested number of colors */
        do    (populate_new_game (ref initial_board, color_num));
        while (bad_colors_number (ref initial_board, color_num)
            || unclickable_board (ref initial_board));

        /* create the board of Tile instances */
        for (uint8 x = 0; x < columns; x++)
            for (uint8 y = 0; y < rows; y++)
                current_board [y, x] = new Tile (view, x, y, initial_board [y, x]);

        is_started = false;
    }
    private static void populate_new_game (ref uint8 [,] initial_board, uint8 color_num)
    {
        uint8 rows    = (uint8) initial_board.length [0];
        uint8 columns = (uint8) initial_board.length [1];
        for (uint8 x = 0; x < columns; x++)
            for (uint8 y = 0; y < rows; y++)
                initial_board [y, x] = (uint8) Math.floor (Random.next_double () * color_num) + 1;
    }
    private static bool bad_colors_number (ref uint8 [,] initial_board, uint8 color_num)
    {
        /* counter will grow to twice the number of colors */
        uint8 counter = 0;
        uint8 [] colors = new uint8 [color_num];
        for (uint8 x = 0; x < color_num; x++)
            colors [x] = 0;

        uint8 rows     = (uint8) initial_board.length [0];
        uint8 columns  = (uint8) initial_board.length [1];
        for (uint8 x = 0; x < columns; x++)
            for (uint8 y = 0; y < rows; y++)
            {
                uint8 color_id = initial_board [y, x];
                /* initial board should be full */
                if (color_id == 0)
                    assert_not_reached ();
                color_id--;
                /* color number too big for given number of colors */
                if (color_id >= color_num)
                    return true;
                /* already (at least) two tiles of this color */
                if (colors [color_id] >= 2)
                    continue;
                /* check if board is now completely good */
                counter++;
                if (counter >= 2 * color_num)
                    return false;
                /* else just increase the per-color counter */
                colors [color_id]++;
            }
        return true;
    }
    private static bool unclickable_board (ref uint8 [,] initial_board)
    {
        uint8 rows     = (uint8) initial_board.length [0];
        uint8 columns  = (uint8) initial_board.length [1];
        for (uint8 x = 1; x < columns; x++)
            for (uint8 y = 0; y < rows; y++)
                if (initial_board [y, x] == initial_board [y, x - 1])
                    return false;
        for (uint8 x = 0; x < columns; x++)
            for (uint8 y = 1; y < rows; y++)
                if (initial_board [y, x] == initial_board [y - 1, x])
                    return false;
        return true;
    }

    /* Recursively find all the connected tile from given_tile */
    private static List<Tile> _connected_tiles_real (Tile? given_tile, ref Tile? [,] current_board)
    {
        List<Tile> cl = new List<Tile> ();

        if (given_tile == null || ((!) given_tile).visited || ((!) given_tile).closed)
            return cl;

        uint8 x = ((!) given_tile).grid_x;
        uint8 y = ((!) given_tile).grid_y;

        ((!) given_tile).visited = true;

        cl.append ((!) given_tile);

        unowned Tile? tile = current_board [y + 1, x];
        if (y + 1 < current_board.length [0]
         && tile != null && (((!) given_tile).color == ((!) tile).color))
            cl.concat (_connected_tiles_real (tile, ref current_board));

        if (y >= 1)
        {
            tile = current_board [y - 1, x];
            if (tile != null && (((!) given_tile).color == ((!) tile).color))
                cl.concat (_connected_tiles_real (tile, ref current_board));
        }

        tile = current_board [y, x + 1];
        if (x + 1 < current_board.length [1]
         && tile != null && (((!) given_tile).color == ((!) tile).color))
            cl.concat (_connected_tiles_real (tile, ref current_board));

        if (x >= 1)
        {
            tile = current_board [y, x - 1];
            if (tile != null && (((!) given_tile).color == ((!) tile).color))
                cl.concat (_connected_tiles_real (tile, ref current_board));
        }

        return cl;
    }

    internal List<Tile> connected_tiles (Tile given_tile)
    {
        return _connected_tiles (given_tile, ref current_board);
    }
    private static List<Tile> _connected_tiles (Tile given_tile, ref Tile? [,] current_board)
    {
        List<Tile> cl = _connected_tiles_real (given_tile, ref current_board);

        foreach (unowned Tile? tile in current_board)
        {
            if (tile != null)
                ((!) tile).visited = false;
        }

        /* single tile will be ignored */
        if (cl.length () < 2)
            return new List<Tile> ();   // technically similar to null, but clearer from Vala pov

        return cl;
    }

    internal void remove_connected_tiles (Tile given_tile)
    {
        remove_connected_tiles_real (given_tile, /* skip history */ false);
    }

    private void remove_connected_tiles_real (Tile given_tile, bool skip_history)
    {
        _remove_connected_tiles (given_tile, ref current_board, skip_history);

        if (!is_started) {
            is_started = true;
            started ();
        }

        if (has_completed (ref current_board))
        {
            if (has_won (ref current_board))
                increment_score (1000);
            complete ();
            is_started = false;
        }
    }
    private void _remove_connected_tiles (Tile given_tile, ref Tile? [,] current_board, bool skip_history)
    {
        List<Tile> cl = _connected_tiles (given_tile, ref current_board);

        if (cl.length () < 2)
            return;

        view.freeze ();

        foreach (unowned Tile tile in (!) cl)
            tile.closed = true;

        uint8 new_x = 0;
        uint8 [] removed_columns = {};

        for (uint8 x = 0; x < columns; x++)
        {
            List<Tile> not_closed_tiles = new List<Tile> ();
            List<Tile> closed_tiles     = new List<Tile> ();

            /* for each column, separate not-closed and closed tiles */
            for (uint8 y = 0; y < rows; y++)
            {
                unowned Tile? tile = current_board [y, x];

                if (tile == null)
                    break;

                if (((!) tile).closed)
                    closed_tiles.append ((!) tile);
                else
                    not_closed_tiles.append ((!) tile);
            }

            /* append closed tiles to not-closed tiles */
            not_closed_tiles.concat ((owned) closed_tiles);

            /* update tile array at the current column, not-closed tiles are at the bottom, closed ones top */
            for (uint8 y = 0; y < rows; y++)
                current_board [y, new_x] = not_closed_tiles.nth_data (y);

            /* flag to check if current column is empty */
            bool has_empty_col = true;

            /* update the positions (grid_x, grid_y) of tiles at the current column */
            for (uint8 y = 0; y < rows; y++)
            {
                unowned Tile? tile = current_board [y, new_x];

                if (tile == null)
                    break;

                if (!((!) tile).closed)
                {
                    ((!) tile).update_position (new_x, y);
                    has_empty_col = false;
                }
            }

            /* If the current column is empty, don't increment new_x. Otherwise increment */
            if (!has_empty_col)
                new_x++;
            else
            {
                int length = removed_columns.length;
                removed_columns.resize (length + 1);
                removed_columns.move (/* start */ 0, /* dest */ 1, /* length */ length);
                removed_columns [0] = new_x;
            }
        }

        /* The remaining columns are do-not-cares. Assign null to them */
        for (; new_x < columns; new_x++)
            for (uint8 y = 0; y < rows; y++)
                current_board [y, new_x] = null;

        view.unfreeze ();

        increment_score_from_tiles ((uint16) cl.length ());

        if (!skip_history)
            add_history_entry (given_tile.grid_x, given_tile.grid_y, given_tile.color, cl, (owned) removed_columns);
    }

    private static bool has_completed (ref Tile? [,] current_board)
    {
        foreach (unowned Tile? tile in current_board)
        {
            if (tile != null && !((!) tile).closed && (_connected_tiles ((!) tile, ref current_board).length () > 1))
                return false;
        }

        return true;
    }

    private static bool has_won (ref Tile? [,] current_board)
    {
        foreach (unowned Tile? tile in current_board)
        {
            if (tile != null && !((!) tile).closed)
                return false;
        }

        return true;
    }

    private inline void decrement_score_from_tiles (uint16 n_tiles)
    {
        increment_score (-1 * get_score_from_tiles (n_tiles));
    }

    private inline void increment_score_from_tiles (uint16 n_tiles)
    {
        increment_score (get_score_from_tiles (n_tiles));
    }

    private inline int get_score_from_tiles (uint16 n_tiles)
    {
        return n_tiles < 3 ? 0 : (n_tiles - 2) * (n_tiles - 2);
    }

    private void increment_score (int variation)
    {
        score += variation;
        update_score (variation);
    }

    /*\
    * * loading and saving
    \*/

    private uint8 [,] initial_board;

    private inline bool load_saved_game (Variant variant)
    {
        if (variant.get_type_string () != "m(aayqa(yy))")
            return false;   // assert_not_reached() ?

        Variant? child = variant.get_maybe ();
        if (child == null)
            return false;

        VariantIter iter = new VariantIter ((!) child);
        Variant? board_variant = iter.next_value ();
        if (board_variant == null)
            assert_not_reached ();
        uint16 history_index;
        iter.next ("q", out history_index);
        Variant? history_variant = iter.next_value ();
        if (history_variant == null)
            assert_not_reached ();

        // all the following way to extract values feels horrible, but there is a bug when trying to do it properly (05/2020)
        Variant? tmp_variant_1 = ((!) board_variant).get_child_value (0);
        if (tmp_variant_1 == null)
            return false;
        uint rows    = (uint) ((!) board_variant).n_children ();
        uint columns = (uint) ((!) tmp_variant_1).n_children ();
        if (rows    != this.rows
         || columns != this.columns)
            return false;

        uint8 [,] initial_board = new uint8 [rows, columns];
        for (uint8 i = 0; i < rows; i++)
        {
            tmp_variant_1 = ((!) board_variant).get_child_value (i);
            for (uint8 j = 0; j < columns; j++)
            {
                Variant tmp_variant_2 = tmp_variant_1.get_child_value (j);
                uint8 color = tmp_variant_2.get_byte ();
                if (color > 4)
                    return false;
                if (color == 0)
                    return false;
                initial_board [rows - i - 1, j] = color;
            }
        }

        if (bad_colors_number (ref initial_board, color_num)
         || unclickable_board (ref initial_board))
            return false;

        Tile? [,] current_board = new Tile? [rows, columns];
        for (uint8 i = 0; i < rows; i++)
            for (uint8 j = 0; j < columns; j++)
                current_board [i, j] = new Tile (view, j, i, initial_board [i, j]);

        iter = new VariantIter ((!) history_variant);
        while (iter != null)
        {
            tmp_variant_1 = iter.next_value ();
            if (tmp_variant_1 == null)
                break;
            _remove_connected_tiles (current_board [rows - tmp_variant_1.get_child_value (1).get_byte () - 1,
                                                    tmp_variant_1.get_child_value (0).get_byte ()],
                                     ref current_board,
                                     /* skip history */ false);
        }

        if (history_index > reversed_history.length ())
        {
            clear_history ();
            return false;
        }

        for (uint16 i = history_index; i != 0; i--)
            undo_real (ref current_board);

        if (has_completed (ref current_board))
        {
            clear_history ();
            return false;
        }

        this.current_board = current_board;
        this.initial_board = initial_board;
        this.history_index = history_index;

        is_started = true;
        return true;
    }

    internal Variant get_saved_game ()
    {
        if (!is_started || has_completed (ref current_board))
            return new Variant ("m(aayqa(yy))", null);

        VariantBuilder builder = new VariantBuilder (new VariantType ("(aayqa(yy))"));
        builder.open (new VariantType ("aay"));
        VariantType ay_type = new VariantType ("ay");
        for (uint8 i = rows; i > 0; i--)
        {
            builder.open (ay_type);
            for (uint8 j = 0; j < columns; j++)
                builder.add ("y", initial_board [i - 1, j]);
            builder.close ();
        }
        builder.close ();
        builder.add ("q", history_index);
        builder.open (new VariantType ("a(yy)"));
        reversed_history.reverse ();
        reversed_history.@foreach ((data) => {
                if (data == null)
                    return;
                builder.open (new VariantType ("(yy)"));
                builder.add ("y", ((!) data).click.x);
                builder.add ("y", rows - ((!) data).click.y - 1);
                builder.close ();
            });
        reversed_history.reverse ();    // get_saved_game might be called once or twice… so let’s put reversed_history back in its (inverted) order
        builder.close ();
        return new Variant.maybe (/* guess the type */ null, builder.end ());
    }

    /*\
    * * history
    \*/

    [CCode (notify = true)] internal bool can_undo { internal get; private set; default = false; }
    [CCode (notify = true)] internal bool can_redo { internal get; private set; default = false; }
    private uint16 history_length = 0;
    private uint16 history_index = 0;

    private List<HistoryEntry> reversed_history = new List<HistoryEntry> ();

    internal signal void undone ();

    private class Point : Object
    {
        public uint8 x { internal get; protected construct; }
        public uint8 y { internal get; protected construct; }

        internal Point (uint8 x, uint8 y)
        {
            Object (x: x, y: y);
        }
    }

    private class HistoryEntry : Object
    {
        [CCode (notify = false)] public Point click { internal get; protected construct; }
        [CCode (notify = false)] public uint8 color { internal get; protected construct; }

        internal List<Point> removed_tiles = new List<Point> ();
        internal uint8 [] removed_columns;

        internal HistoryEntry (uint8 x, uint8 y, uint8 color, List<Tile> cl, owned uint8 [] removed_columns)
        {
            Object (click: new Point (x, y), color: color);
            this.removed_columns = removed_columns;

            // TODO init at construct
            foreach (unowned Tile tile in cl)
                removed_tiles.prepend (new Point (tile.grid_x, tile.grid_y));
            removed_tiles.sort ((tile_1, tile_2) => {
                    if (tile_1.x < tile_2.x)
                        return -1;
                    if (tile_1.x > tile_2.x)
                        return 1;
                    if (tile_1.y < tile_2.y)
                        return -1;
                    if (tile_1.y > tile_2.y)
                        return 1;
                    assert_not_reached ();
                });
        }
    }

    private inline void clear_history ()
    {
        reversed_history = new List<HistoryEntry> ();
        history_length = 0;
        history_index = 0;
        can_undo = false;
        can_redo = false;
    }

    private inline void add_history_entry (uint8 x, uint8 y, uint8 color, List<Tile> cl, owned uint8 [] removed_columns)
    {
        while (history_index > 0)
        {
            unowned HistoryEntry? history_data = reversed_history.nth_data (0);
            if (history_data == null) assert_not_reached ();

            reversed_history.remove ((!) history_data);

            history_index--;
            history_length--;
        }

        reversed_history.prepend (new HistoryEntry (x, y, color, cl, (owned) removed_columns));
        history_length++;
        can_undo = true;
        can_redo = false;
    }

    internal void undo ()
    {
        undo_real (ref current_board);
    }

    private void undo_real (ref Tile? [,] current_board)
    {
        if (!can_undo)
            return;

        unowned List<HistoryEntry>? history_item = reversed_history.nth (history_index);
        if (history_item == null) assert_not_reached ();

        unowned HistoryEntry? history_data = ((!) history_item).data;
        if (history_data == null) assert_not_reached ();

        undo_move ((!) history_data, ref current_board);

        if (history_index == history_length)
            can_undo = false;
        can_redo = true;
    }
    private inline void undo_move (HistoryEntry history_entry, ref Tile? [,] current_board)
    {
        if (has_won (ref current_board))
            increment_score (-1000);
        decrement_score_from_tiles ((uint16) history_entry.removed_tiles.length ());

        view.freeze ();

        foreach (uint8 removed_column in history_entry.removed_columns)
        {
            for (uint8 j = columns - 1; j > removed_column; j--)
            {
                for (uint8 i = 0; i < rows; i++)
                {
                    if (current_board [i, j - 1] != null)
                    {
                        current_board [i, j] = (owned) current_board [i, j - 1];
                        ((!) current_board [i, j]).update_position (j, i);
                    }
                    else
                        current_board [i, j] = null;
                }
            }
            for (uint8 i = 0; i < rows; i++)
                current_board [i, removed_column] = null;
        }

        foreach (unowned Point removed_tile in history_entry.removed_tiles)
        {
            uint8 column = removed_tile.x;
            for (uint8 row = rows - 1; row > removed_tile.y; row--)
            {
                if (current_board [row - 1, column] != null)
                {
                    current_board [row, column] = (owned) current_board [row - 1, column];
                    ((!) current_board [row, column]).update_position (column, row);
                }
                else
                    current_board [row, column] = null;
                if (row == 0)
                    break;
            }
            current_board [removed_tile.y, column] = new Tile (view, column, removed_tile.y, history_entry.color);
        }

        view.unfreeze ();

        history_index++;

        undone ();
    }

    internal void redo ()
    {
        if (!can_redo)
            return;

        unowned List<HistoryEntry>? history_item = reversed_history.nth (history_index - 1);
        if (history_item == null) assert_not_reached ();

        unowned HistoryEntry? history_data = ((!) history_item).data;
        if (history_data == null) assert_not_reached ();

        redo_move ((!) history_data);

        if (history_index == 0)
            can_redo = false;
        can_undo = true;
    }
    private inline void redo_move (HistoryEntry history_entry)
    {
        history_index--;

        // TODO save for real where the user clicked; warning, history_entry.click does not use the same coords system
        remove_connected_tiles_real (current_board [history_entry.removed_tiles.first ().data.y,
                                                    history_entry.removed_tiles.first ().data.x],
                                     /* skip history */ true);
    }
}
