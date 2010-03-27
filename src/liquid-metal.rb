# Copyright (C) 2007-2010 Stephen Bach
#
# Permission is hereby granted to use and distribute this code, with or without
# modifications, provided that this copyright notice is copied with it. Like
# anything else that's free, this file is provided *as is* and comes with no
# warranty of any kind, either expressed or implied. In no event will the
# copyright holder be liable for any damages resulting from the use of this
# software.

# Port of Ryan McGeary's LiquidMetal fuzzy matching algorithm found at:
#   http://github.com/rmm5t/liquidmetal/tree/master.
module LiquidMetal
  @@SCORE_NO_MATCH = 0.0
  @@SCORE_MATCH = 1.0
  @@SCORE_TRAILING = 0.8
  @@SCORE_TRAILING_BUT_STARTED = 0.90
  @@SCORE_BUFFER = 0.85

  def self.score(string, abbrev)

    return @@SCORE_TRAILING if abbrev.empty?
    return @@SCORE_NO_MATCH if abbrev.length > string.length

    scores = buildScoreArray(string, abbrev)

    # Faster than Array#inject...
    sum = 0.0
    scores.each { |x| sum += x }

    return sum / scores.length;
  end

  def self.buildScoreArray(string, abbrev)
    scores = Array.new(string.length)
    lower = string.downcase()

    lastIndex = 0
    started = false

    abbrev.downcase().each_char do |c|
      index = lower.index(c, lastIndex)
      return scores.fill(@@SCORE_NO_MATCH) if index.nil?
      started = true if index == 0

      if index > 0 and " ._-".include?(string[index - 1])
        scores[index - 1] = @@SCORE_MATCH
        scores.fill(@@SCORE_BUFFER, lastIndex...(index - 1))
      elsif string[index] >= ?A and string[index] <= ?Z
        scores.fill(@@SCORE_BUFFER, lastIndex...index)
      else
        scores.fill(@@SCORE_NO_MATCH, lastIndex...index)
      end

      scores[index] = @@SCORE_MATCH
      lastIndex = index + 1
    end

    trailing_score = started ? @@SCORE_TRAILING_BUT_STARTED : @@SCORE_TRAILING
    scores.fill(trailing_score, lastIndex)
    return scores
  end
end

