require 'music_composer'

include MusicComposer

Song.create('d_lament.mid') do
  title "D'Lament"
  add :violin, :name => 'Bernie'
  add :cello, :name => 'Dalia'
  add :piano, :name => 'Gema'
  tempo :moderatto
  time_signature 3, :on => 4

  bernie.basic_rythm(2.nd(Do), Do, Mi)
  dalia.basic_rythm(Fa, 2.nd(Fa), Mi)
  gema.basic_rythm(Mi, Do, 2.nd(Do))

  bernie.starts
  dalia.starts(1.bar.after(bernie))
  gema.starts(1.bar.after(dalia), :for => 3.bars)

  bernie.sounds_for 6.bars
  dalia.sounds_for 6.bars
  #gema.sounds_for 3.bars

  dalia.continues :for => 1.bar
end
