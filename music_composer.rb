require 'midilib'
require 'log4r'

module MusicComposer
  Do, Re, Mi, Fa, Sol, La, Si = 64, 66, 68, 69, 71, 73, 75 #2nd Do is 76
  C, D, E, F, G, A, B = 64, 66, 68, 69, 71, 73, 75
  Tempo = {:moderatto => 120}
  Instrument = {:piano => 0, :violin => 40, :cello => 42}

  class Song
    attr_accessor :beats_per_bar
    def initialize(filename)
      @filename = filename
      @musicians = []
      @logger = Log4r::Logger.new 'music_composer'
      @logger.outputters = Log4r::Outputter.stdout
    end
    def self.create(filename, options = {}, &block)
      song = Song.new(filename)
      song.instance_eval(&block)
      song.write unless options[:in_memory]
      song
    end
    def write
      sequence = MIDI::Sequence.new
      track = MIDI::Track.new(sequence)
      sequence.tracks << track
      track.events << @tempo
      track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, @title)

      delta = sequence.note_to_delta(@beat_length_name)

      @musicians.each do |m|
        t = MIDI::Track.new(sequence)
        sequence.tracks << t
        t.name = m.name
        t.instrument = MIDI::GM_PATCH_NAMES[m.instrument]
        t.events << MIDI::Controller.new(0, MIDI::CC_VOLUME, 127)
        t.events << MIDI::ProgramChange.new(0, 1, 0)
        m.play_on(t, :with => delta, :at => @beats_per_bar)
        t.recalc_delta_from_times
      end

      File.open(@filename, 'wb') { | file | sequence.write(file) }
    end
    def title(title)
      @title = title
    end
    def add(instrument, options)
      name = options[:name]
      musician = Musician.new(name, instrument, self)
      @musicians << musician
      Song.add(name.downcase.to_sym) { musician }
    end
    def self.add(name, &block)
      define_method(name, &block)
    end
    def tempo(tempo)
      @tempo = MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(Tempo[tempo]))
    end
    def time_signature(beats, options = {})
      @beats_per_bar = beats
      @beat_length = options[:on]
      @beat_length_name = case options[:on]
                     when 8
                       'eighth'
                     else
                       'quarter'
                     end
    end
  end
  class Musician
    attr_accessor :name, :instrument
    def initialize(name, instrument, song)
      @name, @instrument, @song = name, Instrument[instrument], song
      @inner_position = 0;
      @ranges = []
      @logger = Log4r::Logger.new @name
      @logger.outputters = Log4r::Outputter.stdout
      #@logger.level = Log4r::WARN
    end
    def next_note
      note = @notes[@inner_position]
      @inner_position = (@inner_position + 1) % @song.beats_per_bar
      note
    end
    def basic_rythm(*notes)
      @notes = notes
    end
    def starts(event = nil, options = nil)
      # In order for the DSL too sound natural, the hash can be the only parameter.
      options, event = event, nil  if event.class == Hash && options.nil?
      if event.nil?
        @ranges << [0]
      else
        mark, length = *event
        offset = mark.latest_beat
        @logger.debug "#{name} plays with a duration of #{offset + length}"
        @ranges << [offset + length]
      end
      sounds_for options[:for] if options
    end
    def continues(event = nil, options = nil)
      # In order for the DSL too sound natural, the hash can be the only parameter.
      options, event = event, nil  if event.class == Hash && options.nil?
    end
    def sounds_for(duration)
      @ranges.last << duration.length
    end
    def latest_beat
      @logger.debug "Latest beat #{@ranges.inspect}"
      @ranges.last.first
    end
    def play_on(track, options = {})
      delta = options[:with]
      length = options[:at]
      counter = 0
      @ranges.each do |r|
        @logger.debug "Start at #{r.first*length}nd beat for #{r.last*length} beats. Time #{delta}. Beats per bar: #{length}"
        ((r.first*length)...(r.first*length + r.last*length)).each do |time|
          note = next_note
          on_event = MIDI::NoteOnEvent.new(0, note, 127, 0)
          off_event = MIDI::NoteOffEvent.new(0, note, 127, delta)
          @logger.debug "#{@name} is playing a #{@instrument} in #{note} at #{time}."
          on_event.time_from_start = time*delta
          off_event.time_from_start = (time+1)*delta
          track.events << on_event
          track.events << off_event
          counter += 1
        end
      end
      @logger.debug counter
    end
  end
  class Duration
    attr_accessor :length
    def initialize(length)
      @length = length
    end
    def after(event)
      [event, @length]
    end
  end
end
class Fixnum
  def bar
    MusicComposer::Duration.new(self)
  end
  alias :bars :bar

  def nd(note)
    note + (self - 1) * 12
  end
end
