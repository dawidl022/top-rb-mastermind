require 'colorize'

def pad_array(arr, to_size)
  Array.new(to_size).each_with_index.map { |_, index| arr[index] }
end

module Validatable
  def put_blank_line
    puts
  end

  def input_option(message, options)
    valid_input = nil
    user_input = nil

    until valid_input
      if user_input
        puts "Invalid input: please enter an integer number."
        put_blank_line
      end

      print message
      user_input = gets.chomp.to_sym
      valid_input = user_input if options.include?(user_input)
    end

    valid_input
  end
end

class MainMenu; end

class HumanGuesser
  include Validatable
  SEPARATOR = "        "

  public

  def guess_colour(colours, slot)
    puts "Available colours:"
    puts format_colours(colours)
    input_option("Please enter your guess for slot #{slot}: ", colours)
  end

  private

  def format_colours(colours)
    colours.map { |colour| colour.to_s.colorize(colour).bold }.join(SEPARATOR)
  end
end

class ComputerMaker
  def choose_colours(colours)
    Array.new(4).map { colours.sample }
  end
end

class Mastermind
  CORRECT_SPOT_MARKER = :red
  CORRECT_COLOUR_MARKER = :white
  CLASSIC_COLOURS = [:red, :magenta, :yellow, :green, :cyan, :blue]

  def initialise(guesser, maker, difficulty, turns, rounds)
    @guesser = guesser
    @maker = maker
    @possible_colours = colours_for_difficulty(difficulty)
    @turns = turns
    @rounds = rounds
    @board = Board.new(number_of_rows: turns)
  end

  public

  def play_game
  end

  private

  def colours_for_difficulty(difficulty)
    case difficulty
    when :medium then CLASSIC_COLOURS
    else raise "Invalid difficulty level"
    end
  end

  def play_round
    chosen_colours = @maker.choose_colours(@possible_colours)

    print_current_board

    (0...@turns).each do |turn|
      hints = grade_guess(chosen_colours, guessed_colours)
      @board.insert_hints(hints)
      print_current_board

      break turn if guesser_won?(hints)

      @board.increment_turn
    end

    # TODO allocate points for round
  end

  def guesser_won?(hints)
    hints.length == 4 && hints.all? { |hint| hint == CORRECT_SPOT_MARKER }
  end

  def guessed_colours
    loop do
      take_guesses
      break if @guesser.confirm_guess
    end
  end

  def take_guesses
    Array.new(4).each_index.map do |i|
      guess = @guesser.guess_colour(@possible_colours, i + 1)

      @board.place_colour(guess, i)
      print_current_board

      guess
    end
  end
end

class Row
  attr_accessor :colours, :hints

  def initialize(colours = nil, hints = nil, size: 4)
    @colours = colours || Array.new(size)
    @hints = hints || Array.new(size)
  end
end

class Board
  ROW_TEMPLATE = [
    "---------------------------",
    "|%s|%s|%s|%s||%s|%s",
    "|%s|%s|%s|%s||-----",
    "---------------------|%s|%s"
  ].freeze

  def initialize(colour_size = 4, hint_size = 2, number_of_rows: 12)
    @colour_size = colour_size
    @hint_size = hint_size
    @number_of_rows = number_of_rows
    @rows = Array.new(@number_of_rows) { Row.new }
    @current_row = 0
  end

  public

  def current_board
    @rows.reverse.map { |row| format_row_template(row.colours, row.hints) }
      .join("\n")
  end

  def increment_turn
    @current_row += 1
  end

  def place_colour(colour, index)
    @rows[@current_row].colours[index] = colour
  end

  def insert_hints(hints)
    @rows[@current_row].hints = hints
  end

  private

  def gen_colorize_proc(rep)
    Proc.new do |colour|
      if colour
        rep.colorize(background: colour)
      else
        rep.colorize(background: :default)
      end
    end
  end


  def format_row_template(colours = Array.new(4), hints = Array.new(4))
    colour_rep = gen_colorize_proc(" " * @colour_size)
    hint_rep = gen_colorize_proc(" " * @hint_size)

    colours = pad_array(colours, 4)
    hints = pad_array(hints, 4)

    ROW_TEMPLATE.each_with_index.map do |row, index|
      if index == 1
        row % colours.map(&colour_rep).concat(hints[0, 2].map(&hint_rep))
      elsif index == 2
        row % colours.map(&colour_rep)
      elsif index == 3
        row % hints[2, 2].map(&hint_rep)
      else
        row
      end
    end.join("\n")
  end
end
