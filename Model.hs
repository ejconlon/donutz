#!/usr/bin/env stack
-- stack --resolver lts-21.16 script --package tasty --package tasty-hunit

type InstName = String

type AbsPitch = Integer

type Shift = Integer

type Duration = Rational

type Tempo = Rational

type Octave = Integer

data PitchClass = C | Cs | D | Ds | E | F | Fs | G | Gs | A | As | B
  deriving stock (Eq, Ord, Show, Bounded, Enum)

data Pitch = Pitch !PitchClass !Octave
  deriving stock (Eq, Ord, Show)

data Score a =
    ScorePrim !Dur !a
  | ScoreSeq !(Score a) !(Score a)
  | ScorePar !(Score a) !(Score a)
  | ScoreMod !Mod (Score a)
  deriving stock (Eq, Ord, Show, Functor, Foldable, Traversable)

data Layout =
    LayoutPack
  | LayoutInst
  deriving (Eq, Ord, Show, Enum, Bounded)

data Mod =
    ModTempo !Rational
  | ModShift !AbsShift
  | ModLayout !Layout
  deriving stock (Eq, Ord, Show)

data NoteAttr
  deriving stock (Eq, Ord, Show)

data Event =
    EventNote !AbsPitch !InstName
  | EventCtl !Ctl
  deriving stock (Eq, Ord, Show)

data StdVal = StdVal !(Maybe Event) ![NoteAttr]
  deriving stock (Eq, Ord, Show)

type StdScore = Score StdVal

data Env = Env !Tempo !Shift !Layout
  deriving stock (Eq, Ord, Show)

type M = RWS Env 

sequence :: StdScore -> [StdVal]
sequence = 

main :: IO ()
main = pure ()

