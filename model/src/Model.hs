module Model where

import Control.Monad.RWS.Strict (RWS, runRWS)

type InstName = String

type AbsPitch = Integer

type AbsShift = Integer

type Duration = Rational

type Tempo = Rational

type Octave = Integer

data PitchClass = C | Cs | D | Ds | E | F | Fs | G | Gs | A | As | B
  deriving stock (Eq, Ord, Show, Bounded, Enum)

data Pitch = Pitch !PitchClass !Octave
  deriving stock (Eq, Ord, Show)

data Score a =
    ScorePrim !Duration !a
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

data NoteAttr = NoteAttr
  deriving stock (Eq, Ord, Show)

data Ctl = CtlOff | CtlCut
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data Event =
    EventNote !AbsPitch !InstName
  | EventCtl !Ctl
  deriving stock (Eq, Ord, Show)

data StdVal = StdVal !(Maybe Event) ![NoteAttr]
  deriving stock (Eq, Ord, Show)

type StdScore = Score StdVal

data Env = Env !Tempo !AbsShift !Layout
  deriving stock (Eq, Ord, Show)

type M = RWS Env () ()

runM :: M a -> Env -> () -> (a, (), ())
runM = runRWS

sequence :: StdScore -> [StdVal]
sequence = undefined

main :: IO ()
main = pure ()

