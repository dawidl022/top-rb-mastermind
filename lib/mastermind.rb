require 'colorize'

# TODO extract all I/O into methods for easy porting to e.g. a GUI

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
        puts "Invalid input. Please input one of the following:"
        puts "#{options.map { |option| "#{option.to_s}" }}"
        put_blank_line
      end

      print message
      user_input = gets.chomp.downcase.to_sym
      valid_input = user_input if options.include?(user_input)
    end

    valid_input
  end

  def yes_no_input(message)
    answer = input_option(message + ' [Y/n]: ', [:yes, :y, :no, :n])

    answer == :yes || answer == :y
  end
end

class MainMenu
  def start
    # TODO update once rest of game logic is settled, add configurable game
    # options from menu
    # guesser = HumanGuesser.new
    # maker = ComputerMaker.new
    guesser = EasyComputerGuesser.new
    maker = HumanMaker.new
    game = Mastermind.new(guesser, maker, :medium, 12, 2)
    game.play_game
  end
end


class Player
  attr_accessor :points

  def initialize
    @points = 0
  end
end

# Easy difficulty, get to colours strategically, then randomly order them
class EasyComputerGuesser < Player
  def initialize
    super
    @last_feedback = Array.new(4)
    @guessed_colours = []
    @guess = Array.new(4)
    @guess_indices = Array.new(4)
  end

  public

  def take_feedback(feedback)
    @last_feedback = feedback
  end

  def guess_colour(colours, slot)
    if slot == 1
      prepare_guess(colours)
    end

    @guess[slot - 1]
  end

  def confirm_guess?
    true
  end

  private

  def prepare_guess(colours)
    old_guess = @guess_indices.clone

    correct = 4 - @last_feedback.count(nil)

    # separate old guesses from new ones
    border = @guessed_colours.length

    # at each guess at most 1 new colour is guessed, at index of border
    newly_found = correct - border
    if newly_found
      @guessed_colours.concat(Array.new(newly_found, old_guess[border]))
    end

    # first guess
    if old_guess == [nil, nil, nil, nil]
      @guess_indices = Array.new(4, 0)

    # keep testing new colours until all are found
    elsif @last_feedback.include?(nil)

      # include already found colours in next guess, pad rest with a new colour
      @guess_indices = @guessed_colours.clone
      left_to_guess = 4 - correct
      @guess_indices.concat(Array.new(left_to_guess, old_guess[border] + 1))

    else
      @guess_indices = @guessed_colours.shuffle
    end

    @guess = @guess_indices.map { |index| colours[index] }
  end
end

class HumanPlayer < Player
  include Validatable

  SEPARATOR = "        "

  private

  def format_colours(colours)
    colours.map { |colour| colour.to_s.colorize(colour).bold }.join(SEPARATOR)
  end
end

class HumanGuesser < HumanPlayer
  public

  def guess_colour(colours, slot)
    puts "Available colours:"
    puts format_colours(colours)
    input_option("Please enter your guess for slot #{slot}: ", colours)
  end

  def confirm_guess?
    yes_no_input("Are you ready to end your turn?")
  end

  def take_feedback
    # Feedback is displayed visually, so no action here
  end
end


class ComputerMaker < Player
  def choose_colours(colours)
    Array.new(4).map { colours.sample }
  end
end

class HumanMaker < HumanPlayer
  def choose_colours(colours)
    puts "Available colours:"
    puts format_colours(colours)

    Array.new(4).each_index.map do |index|
      slot = index + 1
      colour = input_option(
        "Please set a colour for slow guess for slot #{slot}: ", colours
      )
    end
  end
end

class Mastermind
  CORRECT_SPOT_MARKER = :red
  CORRECT_COLOUR_MARKER = :white
  CLASSIC_COLOURS = [:red, :magenta, :yellow, :green, :cyan, :blue]

  def initialize(guesser, maker, difficulty, turns, rounds)
    if rounds.even?
      @rounds = rounds
    else
      raise "Number of rounds must be even!"
    end

    @guesser = guesser
    @maker = maker
    @possible_colours = colours_for_difficulty(difficulty)
    @turns = turns
    @board = Board.new(number_of_rows: turns)
  end

  public

  def play_game
    @rounds.times do
      play_round
      # TODO remove break
      break
    end

    # temporary result of game
    puts "Maker scored #{@maker.points} points."
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

    turns_played = (1..@turns).each do |turn|
      hints = grade_guess(chosen_colours, guessed_colours)
      @board.insert_hints(hints)
      @guesser.take_feedback(hints)
      print_current_board

      break turn if guesser_won?(hints) || turn == @turns

      @board.increment_turn
    end

    allocate_score(turns_played)
  end

  def guesser_won?(hints)
    hints.length == 4 && hints.all? { |hint| hint == CORRECT_SPOT_MARKER }
  end

  def guessed_colours
    loop do
      guesses = take_guesses
      break guesses if @guesser.confirm_guess?
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

  def print_current_board
    puts @board.current_board
  end

  def grade_guess(answer, guess)
    colours_left = answer.clone

    mark_colour = Proc.new do |colour|
      pos_to_remove = colours_left.index(colour)
      colours_left.delete_at(pos_to_remove) if pos_to_remove
    end

    grade = guess.each_with_index.map do |guessed_colour, index|
      # Check for colours in correct positions
      if guessed_colour == answer[index]
        # Mark colour as already handled to avoid duplicate (redundant) feedback
        mark_colour.call(guessed_colour)
        CORRECT_SPOT_MARKER
      end
    end.each_with_index.map do |previous_result, index|
      # Check for correct colours but in wrong positions
      guessed_colour = guess[index]
      if guessed_colour != answer[index] && colours_left.include?(guessed_colour)
        mark_colour.call(guessed_colour)
        CORRECT_COLOUR_MARKER
      else
        previous_result
      end
    end

    shuffle_differently(grade)
  end

  def allocate_score(turns)
    if turns == 12
      @maker.points += 13
    else
      @maker.points += turns
    end
  end

  def shuffle_differently(array)
    if array.tally.length <= 1
      return array
    end

    shuffled = array
    while shuffled == array
      shuffled = array.shuffle
    end
    shuffled
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

if __FILE__ == $PROGRAM_NAME
  MainMenu.new.start
end
