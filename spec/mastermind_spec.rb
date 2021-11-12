require_relative '../lib/mastermind'
require 'stringio'

RSpec.describe "#pad_array returns" do
  it "an array of nils given an empty array and positive size" do
    expect(pad_array([], 4)).to eq([nil, nil, nil, nil])
  end

  it "an untouched array given the same number of elements as the size" do
    orig_array = [1, 2, 3, 4]
    expect(pad_array(orig_array, orig_array.size)).to eq(orig_array)
  end

  it "an array padded with nil up to the size" do
    expect(pad_array([1, 2], 5)).to eq([1, 2, nil, nil, nil])
  end

  it "a truncated array when given more elements than the size" do
    expect(pad_array([1, 2, 3, 4], 2)).to eq([1, 2])
  end
end

RSpec.describe Row do
  it "stores colours and hints as nil elements given no arguments" do
    row = Row.new
    aggregate_failures do
      expect(row.colours).to eq([nil, nil, nil, nil])
      expect(row.hints).to eq([nil, nil, nil, nil])
    end
  end

  it "stored given colours and hints" do
    colours = [:red, :green, :blue, :yellow]
    hints = [:red, :white, :white]
    row = Row.new(colours, hints)
    aggregate_failures do
      expect(row.colours).to eq(colours)
      expect(row.hints).to eq(hints)
    end
  end

end

RSpec.describe Board do
  let(:board) { described_class.new }

  def row_with_colours_and_hints(colours, hints)
    "---------------------------\n" \
    "|#{"    ".colorize(background: colours[0])}|" \
    "#{"    ".colorize(background: colours[1])}|" \
    "#{"    ".colorize(background: colours[2])}|" \
    "#{"    ".colorize(background: colours[3])}||" \
    "#{"  ".colorize(background: hints[0])}|" \
    "#{"  ".colorize(background: hints[1])}\n" \
    "|#{"    ".colorize(background: colours[0])}|" \
    "#{"    ".colorize(background: colours[1])}|" \
    "#{"    ".colorize(background: colours[2])}|" \
    "#{"    ".colorize(background: colours[3])}||-----\n" \
    "---------------------|" \
    "#{"  ".colorize(background: hints[2])}|" \
    "#{"  ".colorize(background: hints[3])}"
  end

  def row_with_colours(colours)
    self.row_with_colours_and_hints(colours, [])
  end

  def empty_row
    @empty_row ||= self.row_with_colours([])
  end

  describe "#format_row_template returns" do
    colours = [:red, :green, :blue, :yellow]

    it "an empty row when no colours are passed" do
      expect(board.send(:format_row_template)).to eq(empty_row)
    end
    it "a row with specified colours" do
      expect(board.send(:format_row_template, colours, [])).to eq(
        row_with_colours(colours))
    end

    it "a row with specified hints" do
      hints = [:red, :white, :white]
      expect(board.send(:format_row_template, colours, hints)).to eq(
        row_with_colours_and_hints(colours, hints)
      )
    end
  end

  describe "#current_board" do
    it "returns board with 12 empty rows when starting game" do
      expect(board.current_board).to eq((empty_row + "\n") * 11 + empty_row)
    end
  end

  describe "#increment_turn" do
    it "increases the current row by one" do
      initial_row = board.instance_variable_get(:@current_row)
      board.increment_turn
      expect(board.instance_variable_get(:@current_row)).to eq(initial_row + 1)
    end
  end

  describe "incrementing turn makes next row fill up" do
    pending
  end

  describe "#place_colour" do
    it "places a colour into specified slot of current row" do
      board.place_colour(:blue, 1)
      expect(board.current_board).to eq((empty_row + "\n") * 11 +
        row_with_colours([nil, :blue, nil, nil])
      )
    end

    it "overwrites a previous colour occupying a spot" do
      board.place_colour(:blue, 1)
      board.place_colour(:red, 1)
      expect(board.current_board).to eq((empty_row + "\n") * 11 +
        row_with_colours([nil, :red, nil, nil])
      )
    end
  end

  describe "#insert_hints" do
    hints = [:red, :white]
    it "inserts a full set of hints into current row" do
      board.insert_hints(hints)
      expect(board.current_board).to eq((empty_row + "\n") * 11 +
        row_with_colours_and_hints([], hints)
      )
    end
  end

end

RSpec::Matchers.define :be_included_in do |expected_collection|
  match do |actual_element|
    expected_collection.include?(actual_element)
  end
end

RSpec.describe ComputerMaker do
  let(:maker) { described_class.new }
  CLASSIC_COLOURS = Mastermind::CLASSIC_COLOURS

  describe "#choose_colours" do
    it "returns a random array of 4 colours out of those given" do
      expect(maker.choose_colours(CLASSIC_COLOURS))
        .to all(be_included_in(CLASSIC_COLOURS))
    end

    it "returns the same result when the seed is the same" do
      srand 100
      first_time = maker.choose_colours(CLASSIC_COLOURS)

      srand 100
      expect(maker.choose_colours(CLASSIC_COLOURS)).to eq(first_time)
    end

    it "returns a different result when the seed is different" do
      srand 100
      first_time = maker.choose_colours(CLASSIC_COLOURS)

      srand 101
      expect(maker.choose_colours(CLASSIC_COLOURS)).not_to eq(first_time)
    end
  end
end

RSpec.describe HumanGuesser do
  let(:guesser) { described_class.new }
  colours = Mastermind::CLASSIC_COLOURS
  let(:input) { StringIO.new }
  let(:output_mock) { double('IO') }

  before do
    $stdin = input
    allow(output_mock).to receive(:write)
  end

  after do
    $stdout = STDOUT
  end

  describe "#guess_colour" do
    before do
      input.string = "cyan\n"
    end

    it "prints possible colours and prompts player to choose for slot 1" do
      expect { guesser.guess_colour(colours, 1) }.to output(
        "Available colours:\n" \
        "#{guesser.send(:format_colours, colours)}\n" \
        "Please enter your guess for slot 1: "
      ).to_stdout
    end

    it "returns the chosen colour" do
      $stdout = output_mock
      expect(guesser.guess_colour(colours, 1)).to eq(:cyan)
    end

    it "prompts for input until it is valid and returns the valid input" do
      input.string = "spam\negg\nred\n"
      $stdout = output_mock

      expect(guesser.guess_colour(colours, 1)).to eq(:red)
    end
  end

  describe "#confirm_guess? is case insensitive and returns" do
    before do
      $stdout = output_mock
    end

    it "true given yes as input" do
      input.string = "Yes\n"
      expect(guesser.confirm_guess?).to be true
    end

    it "false given no as input" do
      input.string = "NO\n"
      expect(guesser.confirm_guess?).to be false
    end
  end
end

RSpec.describe Mastermind do
  # STUB players and pass arguments to new method
  let(:game) do
    maker = double("ComputerMaker")
    guesser = double("HumanGuesser")
    described_class.new(guesser, maker, :medium, 12, 2)
  end
  CORRECT_COLOUR = described_class::CORRECT_COLOUR_MARKER
  CORRECT_SPOT = described_class::CORRECT_SPOT_MARKER

  describe "#grade_guess" do
    answer = [:red, :green, :yellow, :magenta]
    guess = [:blue, :blue, :red, :magenta]
    expected_outcome = [nil, nil, CORRECT_COLOUR, CORRECT_SPOT]
    let(:actual) { game.send(:grade_guess, answer, guess) }

    it "returns an array" do
      expect(actual.class).to be Array
    end

    it "the grade does not depict the positioning on the board" do
      expect(actual).to_not eq(expected_outcome)
    end

    it "has the same elements as expected" do
      expect(actual.tally).to eq(expected_outcome.tally)
    end

    describe "handles edge case" do
      before do
        # DISABLE SCRAMBLING OF FEEDBACK
        allow(game).to receive(:shuffle_differently) do |array|
          array
        end
      end

      describe "more duplicate colours guessed than in answer" do

        it 'all in correct position' do
          answer = [:red, :red, :blue, :blue]
          guess = [:red, :red, :red, :blue]
          expected_outcome = [CORRECT_SPOT, CORRECT_SPOT, nil, CORRECT_SPOT]

          expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
        end

        it '1 in correct position' do
          answer = [:red, :red, :blue, :blue]
          guess = [:blue, :red, :red, :red]
          expected_outcome = [CORRECT_COLOUR, CORRECT_SPOT, CORRECT_COLOUR, nil]

          expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
        end

        it '1 in correct position, different position' do
          answer = [:red, :red, :red, :blue]
          guess = [:blue, :blue, :red, :red]
          expected_outcome = [CORRECT_COLOUR, nil, CORRECT_SPOT, CORRECT_COLOUR]

          expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
        end

        it '1 in correct position, 2 not in correct position, 1 redundant' do
          answer = [:yellow, :yellow, :magenta, :magenta]
          guess = [:magenta, :magenta, :yellow, :magenta]
          expected_outcome = [CORRECT_COLOUR, nil, CORRECT_COLOUR, CORRECT_SPOT]

          expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
        end
      end

      it 'starting colour not correct when when redundant in solution' do
        answer = [:yellow, :yellow, :magenta, :magenta]
        guess = [:magenta, :yellow, :magenta, :magenta]
        expected_outcome = [nil, CORRECT_SPOT, CORRECT_SPOT, CORRECT_SPOT]

        expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
      end

      it 'all colours in wrong position, but correct' do
        answer = [:yellow, :yellow, :magenta, :magenta]
        guess = [:magenta, :magenta, :yellow, :yellow]
        expected_outcome = Array.new(4, CORRECT_COLOUR)

        expect(game.send(:grade_guess, answer, guess)).to eq(expected_outcome)
      end
    end
  end

  describe "#shuffle_differently" do
    it "returns different array if possible" do
      input_array = [CORRECT_COLOUR, nil, CORRECT_SPOT, CORRECT_COLOUR]
      expect(game.send(:shuffle_differently, input_array)).to_not eq(input_array)
    end

    it "returns same array when all elements are the same" do
      input_array = Array.new(4, CORRECT_SPOT)
      expect(game.send(:shuffle_differently, input_array)).to eq(input_array)
    end
  end
end
