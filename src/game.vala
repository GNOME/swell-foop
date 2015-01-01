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
public class Tile : Object
{
    /* Property */
    private bool _closed = false;
    public bool closed
    {
        get { return _closed; }
        set
        {
            _closed = value;
            /* Send close signal */
            if (_closed)
                close (grid_x, grid_y);
        }
    }

    public int grid_x;
    public int grid_y;
    public int color;
    public bool visited = false;

    /* Signals */
    public signal void move (int old_x, int old_y, int new_x, int new_y);
    public signal void close (int grid_x, int grid_y);

    /* Constructor */
    public Tile (int x, int y, int c)
    {
        grid_x = x;
        grid_y = y;
        color  = c;
    }

    /* Do not use this mothod to initialize the position. */
    public void update_position (int new_x, int new_y)
    {
        var old_x = grid_x;
        var old_y = grid_y;

        if ((new_x != old_x) || (new_y != old_y))
        {
            grid_x = new_x;
            grid_y = new_y;

            /* Send move signal to actor in the view */
            if (!closed)
                move (old_x, old_y, new_x, new_y);
        }
    }
}

/**
 *  This is the model layer of the whole game. All game logic goes here. This class tries not to
 *  bring in any visual stuff to comply the separation of view-model idea.
 */
public class Game : Object
{
    private Tile[,] tiles;
    private bool is_started = false;

    /* Game score */
    public int score { get; set; default = 0; }

    private int _color_num = 3;
    public int color_num
    {
        get { return _color_num; }
        set
        {
            if (value < 2 || value > 4)
                _color_num = 3;
            else
                _color_num = value;
        }
    }

    /* Property */
    public int rows { get; set; default = 8; }
    public int columns { get; set; default = 8; }

    public signal void update_score (int points_awarded);
    public signal void complete ();
    public signal void started ();

    /* Constructor */
    public Game (int rows, int columns, int color_num)
    {
        _rows = rows;
        _columns = columns;
        _color_num = color_num;

        /* A 2D array holds all tiles */
        tiles = new Tile [rows, columns];

        for (var x = 0; x < columns; x++)
        {
            for (var y = 0; y < rows; y++)
            {
                int c = (int) Math.floor (Random.next_double () * color_num);
                tiles[y, x] = new Tile (x, y, c);
            }
        }

        is_started = false;
    }

    /* Recursively find all the connected tile from li */
    private List<Tile> _connected_tiles (Tile? li)
    {
        var cl = new List<Tile> ();

        if (li.visited || li.closed)
            return cl;

        var x = li.grid_x;
        var y = li.grid_y;

        li.visited = true;

        cl.append (li);

        if ((y + 1) < rows && tiles[y + 1, x] != null && (li.color == tiles[y + 1, x].color))
            cl.concat (_connected_tiles (tiles[y + 1, x]));

        if ((y - 1) >= 0 && tiles[y - 1, x] != null && (li.color == tiles[y - 1, x].color))
            cl.concat (_connected_tiles (tiles[y - 1, x]));

        if ((x + 1) < columns && tiles[y, x + 1] != null && (li.color == tiles[y, x + 1].color))
            cl.concat (_connected_tiles (tiles[y, x + 1]));

        if ((x - 1) >= 0 && tiles[y, x - 1] != null && (li.color == tiles[y, x - 1].color))
            cl.concat (_connected_tiles (tiles[y, x - 1]));

        return cl;
    }

    public List<Tile> connected_tiles (Tile li)
    {
        foreach (var l in tiles)
        {
            if (l != null)
                l.visited = false;
        }

        List<Tile> cl = _connected_tiles (li);

        /* single tile will be ignored */
        if (cl.length () < 2)
            cl = null;

        return cl;
    }

    public Tile get_tile (int x, int y)
    {
        return tiles[y, x];
    }

    public bool remove_connected_tiles (Tile tile)
    {
        List<Tile> cl = connected_tiles (tile);

        if (cl == null)
            return false;

        foreach (var l in cl)
            l.closed = true;

        int new_x = 0;

        for (int x = 0; x < columns; x++)
        {
            var not_closed_tiles = new List<Tile> ();
            var closed_tiles = new List<Tile> ();

            /* for each column, separate not-closed and closed tiles */
            for (int y = 0; y < rows; y++)
            {
                var li = tiles[y, x];

                if (li == null)
                    break;

                if (li.closed)
                    closed_tiles.append (li);
                else
                    not_closed_tiles.append (li);
            }

            /* append closed tiles to not-closed tiles */
            not_closed_tiles.concat ((owned) closed_tiles);

            /* update tile array at the current column, not-closed tiles aret at the bottom, closed ones top */
            for (int y = 0; y < rows; y++)
                tiles[y, new_x] = not_closed_tiles.nth_data (y);

            /* flag to check if current column is empty */
            var has_empty_col = true;

            /* update the positions (grid_x, grid_y) of tiles at the current column */
            for (int y = 0; y < rows; y++)
            {
                var l = tiles[y, new_x];

                if (l == null)
                    break;

                l.update_position (new_x, y);

                if (!l.closed)
                    has_empty_col = false;
            }

            /* If the current column is empty, don't increment new_x. Otherwise increment */
            if (!has_empty_col)
                new_x++;
        }

        /* The remaining columns are do-not-cares. Assign null to them */
        for (; new_x < columns; new_x++)
            for (int y = 0; y < rows; y++)
                tiles[y, new_x] = null;

        increment_score_from_tiles ((int)cl.length ());

        if (!is_started) {
            is_started = true;
            started ();
        }

        if (this.has_completed ())
        {
            if (this.has_won ())
                increment_score (1000);
            complete ();
        }

        return false;
    }

    public void reset_visit ()
    {
        foreach (var l in tiles)
        {
            if (l != null)
                l.visited = false;
        }
    }

    public bool has_completed ()
    {
        foreach (var l in tiles)
        {
            if (l != null && !l.closed && (connected_tiles (l).length () > 1))
                return false;
        }

        return true;
    }

    public bool has_won ()
    {
        foreach (var l in tiles)
        {
            if (l != null && !l.closed)
                return false;
        }

        return true;
    }

    public void increment_score_from_tiles (int n_tiles)
    {
        var points_awarded = 0;

        if (n_tiles >= 3)
            points_awarded = (n_tiles - 2) * (n_tiles - 2);

        increment_score (points_awarded);
    }

    public void increment_score (int increment)
    {
        score += increment;
        update_score (increment);
    }
}
