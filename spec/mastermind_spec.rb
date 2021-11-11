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
    input.string = "cyan\n"
    allow(output_mock).to receive(:write)
  end

  describe "#guess_colour" do
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
end

RSpec.describe Mastermind do

end
