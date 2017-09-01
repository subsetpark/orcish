## Nim port of orcish language converter by @pomalley.
import tables, random, options, hashes, algorithm
from strutils import `%`

proc hash(o: Option[char]): Hash =
  if o.isSome: hash(o.get)
  else: hash(' ')

randomize()

const
  # English Letter Categories
  baseVowels = [
    'a', 'e', 'i', 'o', 'u'
  ]
  baseHardConsonants = [
    'b', 'c', 'd', 'f', 'g', 'j', 'k', 'p', 'q', 't', 'v', 'x', 'y', 'z'
  ]
  baseSoftConsonants = ['h', 'l', 'n', 'r', 's', 'm', 'w', ]
  # Orcish Letter targets (duplicates allow for weighted probabilities)
  targetVowels = [
    'a', 'e', 'o', 'u', 'a', 'e', 'o', 'a', 'o', 'i', '\''
  ]
  targetHardConsonants = [
    'b', 'c', 'd', 'f', 'g', 'j', 'k', '\'', 'n', 'p', 'r', 't', 'h', 'z', 'g', 'k', 't', 'g', '\''
  ]
  targetSoftConsonants = [
    'r', 'n', 'h', 'm', 'r', 'n', 'w', 's'
  ]
  upperChars = {'A'..'Z'}

type
  cacheKey = tuple[c: char, previous: Option[char], seed: int]
  validityCacheKey = tuple[c: char, previous: Option[char]]

# Character properties

proc canStartWord(c: char): bool {.inline.} = c != '\''
proc mustStartSyllable(c: char): bool {.inline.} = c in {'f', 'b', 'w', 'j', 'n'}
proc invalidLeadUps(c: char): set[char] =
  case c
  of 'b': {'p', 'f', 'g', 't', 'k', 'c', 'h', 'n'}
  of 'c': {'d', 'f', 'g', 'h', 'k', 'p', 't', 'z', }
  of 'd': {'h', 'c', 'g', 'p', 't', 'z', 'k', }
  of 'm': {'n', 'h', 'c', 'f', 'g', 'k', 'p', 'z', 'i', }
  of 'g': {'c', 'f', 'p', 'z', }
  of 'j': {'c', 'd', 'g', 'z', }
  of 'k': {'d', 'p', 'z', 'g', }
  of 'n': {'c', 'd', 'f', 'j', 'z', 'm', }
  of 'p': {'d', 'g', 't', }
  of 't': {'d', 'g', }
  of 'r': {'n', 'z', 'm', }
  of 'h', 'w': {'i', }
  else: {}

proc isValid(c: char, previous: Option[char]): bool =
  var cache {.global.} = newTable[validityCacheKey, bool]()
  let key = (c, previous)

  if not previous.isSome:
    result = c.canStartWord
  elif c == previous.get:
    result = false
  elif key in cache:
    result = cache[key]
  else:
    if c.mustStartSyllable and previous.get notin baseVowels:
      result = false
    elif previous.isSome and previous.get in c.invalidLeadUps:
      result = false
    else:
      result = true

    cache[key] = result

# Garbling procedures

proc garble[T: static[int]](chars: array[T, char], c: char, jumpBy: int): char =
  let
    index = chars.binarySearch(c)
  if index == -1:
    result = c
  else:
    let i = (index + jumpBy) mod T
    result = chars[i]

proc garble(c: char, previous: Option[char], jumpBy: int): char =
  result = c
  var
    i = 0
  while i <= 8 and (result == c or not c.isValid(previous)):
    result = case c
      of baseHardConsonants: targetHardConsonants.garble(c, jumpBy + i)
      of baseSoftConsonants: targetSoftConsonants.garble(c, jumpBy + i)
      of baseVowels: targetVowels.garble(c, jumpBy + i)
      else: c
    i += 1

proc garble(sentence: string, proficiency = 0.0): string =
  ## Given a string of English text, partially garble it into Orcish.
  var cache {.global.} = newTable[cacheKey, char]()

  proc passesProficiency(): bool = proficiency > 0 and proficiency >= random(1.0)

  result = sentence
  if proficiency >= 1:
    return

  var previousChar = none(char)
  for character in result.mitems:

    if character in strutils.Whitespace:
      previousChar = none(char)
      continue
    # Roll to see if character shows in English
    elif passesProficiency():
      continue

    let upperCased = character in upperChars
    var
      currentChar = if upperCased: (character.int + 32).char else: character
      garbledChar = currentChar

    let
      randomSeed = random(5)
      key = (c: character, previous: previousChar, seed: randomSeed)

    if key notin cache:
      cache[key] = currentChar.garble(previousChar, randomSeed)

    garbledChar = cache[key]
    previousChar = some garbledChar

    if upperCased:
      garbledChar = (garbledChar.int - 32).char

    character = garbledChar

when isMainModule:
  import os
  let arguments = commandLineParams()
  if arguments.len == 0:
    let proficiency = random(1.0)
    const speech = """
    We are the fighting Uruk-hai! We slew the great warrior. We took the
    prisoners. We are the servants of Saruman the Wise, The White Hand: The Hand
    that gives us man's-flesh to eat. We came out of Isengard, and led you here,
    and we shall lead you back by the way we choose.
    """
    echo garble(speech, proficiency)
  else:
    let filename = arguments[0]
    for line in filename.lines:
      let
        proficiency = random(1.0)
        garbled = garble(line, proficiency)

      when defined(silent):
        continue
      else:
        echo garbled
