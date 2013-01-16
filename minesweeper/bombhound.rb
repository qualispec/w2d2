require 'yaml'

class Board
  attr_accessor :board

  def initialize_play(num)
    @rows = num - 1
    @columns = num - 1
    @bomb_number = num_bombs(num)
    @board = {}
    @bombs = []
  end

  def play
    if @board.nil?
      puts "Do you want a (1) 9 x 9 grid or (2) 16 x 16 grid" 
      grid_number = gets.chomp.to_i
      if grid_number == 1
        initialize_play(9)
      else
        initialize_play(16)
      end
      create_board
    end

    until win?
      print_board
      player_move = get_player_move
      location = player_move[1..2]
      if player_move[0] == "r"
        if @board[location].flagged
          puts "Can't reveal a flagged tile. Please unflag first."
        elsif @board[location].bomb
          puts "You LOSE!"
          break
        else
          reveal_location(location)
        end
      elsif player_move[0] == 'q'
        puts "You are about to quit, save board? (y/n)"
        input = gets.chomp.downcase
        if input[0] == 'y'
          save
          Kernel::exit
        else
          Kernel::exit
        end
      else
        if @board[location].flagged
          @board[location].unflag
        else
          @board[location].flag
        end
      end
    end

    puts "Congrats! You've won" if win?
    puts "Play again? (y/n)"
    input = gets.chomp.downcase
    if input[0] == 'y'
      play
    else
      puts "Thanks for playing!"
    end
  end

  def win?
    flags = @board.select{ |location| @board[location].flagged }
    if flags.count == @bomb_number
      flags.all? { |location| location[1].bomb }
    else
      false
    end
  end

  def reveal_location(location)
    @board[location].reveal
    if @board[location].nearby_bombs > 0
      # Do nothing
    else
      #recurse!
      nearbies = @board[location].nearby_tiles
      nearbies.each do |location|
        unless @board[location].showing || @board[location].flagged
          reveal_location(location)
        end
      end
    end
  end

  def print_board
    r = 0
    print "   "
    (0..@columns).each {|column| print " #{column.to_s.rjust(2,"0")} "}
    puts
    until r == @rows + 1
      render_rows(r)
      r += 1
    end
  end

  def render_rows(r)
    c = 0
    if r <= 9
      print " 0#{r} "
    else
      print " #{r} "
    end

    until c == @columns + 1
      @board[[r, c]].print_tile
      c += 1
    end
    puts
  end

  # Returns array with player move type and move location
  def get_player_move
    puts "Make your move - (f)lag/(r)eveal followed by #row #column."
    puts "Example: r 3 4"
    tile_choice = gets.chomp.downcase.split(" ")
    tile_choice[1..2] = tile_choice[1..2].map(&:to_i)

    if valid?(tile_choice)
      tile_choice
    else
      puts "Please enter in the form: 'r 3 4'"
      get_player_move
    end
  end

  # Checks if player inputs a valid move
  def valid?(tile_choice)
    if tile_choice[0] == "r" || tile_choice[0] == "f" ||  tile_choice[0] == "q"
      if tile_choice[0] == 'q'
        return true
      elsif @board[tile_choice[1..2]]
        return true
      end
    end
    false
  end

  def num_bombs(num)
    case num
    when 4 then 1
    when 9 then 10
    when 16 then 40
    end
  end

  def tile_locations
    tiles = []
    (0..@rows).each do |row|
      (0..@columns).each do |column|
        tiles << [row, column]
      end
    end
    tiles
  end

  def bomb_locations(locations)
    locations.sample(@bomb_number)
  end

  def create_board
    locations = tile_locations
    @bombs = bomb_locations(locations)

    set_tiles(locations, @bombs)

    assign_nearby_tiles
    assign_nearby_bombs
  end

  # Creates a tile object at each board location
  def set_tiles(locations, bombs)
    locations.each do |location|
      if bombs.include?(location)
        @board[location] = Tile.new(location, true)
      else
        @board[location] = Tile.new(location)
      end
    end
  end

  # Adds a nearby tiles array to each tile object on the board
  def assign_nearby_tiles
    @board.each do |location, tile_object|
      nearby_locations = find_nearby_locations(location)
      pruned_locations = prune_nearby_locations(nearby_locations)
      tile_object.nearby_tiles += pruned_locations
    end
  end

  def assign_nearby_bombs
    @board.each_value do |tile_object|
      tile_object.fix_nearby_bombs(@board)
    end
  end

  #Returns all possible locations one square away from argument
  def find_nearby_locations(location)
    row, column = location
    nearby_locations = []
    r = -1
    until r == 2
      c = -1
      until c == 2
        nearby_locations << [row + r, column + c] unless r == 0 && c == 0
        c += 1
      end
      r += 1
    end
    nearby_locations
  end

  # Returns only locations that exist on board
  def prune_nearby_locations(nearby_locations)
    nearby_locations.select { |loc| @board[loc]}
  end

  def save
    puts "What would you like to call your game?"
    game_name = gets.chomp.downcase
    saved_game = self.to_yaml
    File.open("#{game_name}.yaml", "w") do |f|
      f.puts saved_game
    end
  end
end

class Tile
  attr_accessor :flagged, :showing, :nearby_tiles, :checked
  attr_reader :bomb, :nearby_bombs

  def initialize(location, bomb=false)
    @location = location
    @bomb = bomb
    @flagged = false
    @showing = false
    @nearby_tiles = []
  end

  def flag
    @flagged = true unless @showing
  end

  def unflag
    @flagged = false
  end

  def reveal
    @showing = true
  end

  def fix_nearby_bombs(board)
    @nearby_bombs = self.nearby_tiles.select{ |location| board[location].bomb }.count
  end

  def print_tile
    if @flagged
      print " F  "
    elsif @showing
      if @nearby_bombs == 0
        print " -  "
      else
        print " #{@nearby_bombs.to_s}  "
      end
    else
      print " *  "
    end
  end
end

game = Board.new
puts "Welcome to Bomb Hound... ready to sniff out some bombs?"
puts "Do you want to load a previous game?"
previous_game = gets.chomp.downcase
if previous_game[0] == 'y'
  puts "Which file?"
  file = gets.chomp
  File.open("#{file}.yaml") { |yf| game = YAML::load(yf) }
end
game.play