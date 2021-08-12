require 'nokogiri'

#=============================================================================
# ** Parser_Call
#---------------------------------------------------------------------------
# Here lies some weird tenhou magic.
#=============================================================================

module Parser_Call

  def self.parse_chi(m)
    t = (m & 0xfc00) >> 10
    t /= 3

    t = 9 * (t / 7) + (t % 7)
    t *= 4

    return [
      t + ((meld & 0x0018) >> 3),
      t + ((meld & 0x0060) >> 5) + 4,
      t + ((meld & 0x0180) >> 7) + 8,
    ].sort
  end

end

#==============================================================================
# ** Game_Player
#==============================================================================

class Game_Player

  attr_reader   :closed_tiles
  attr_reader   :discards
  attr_reader   :open_tiles
  attr_reader   :riichi_tile

  def initialize
    @closed_tiles = []
    @open_tiles = []
    @discards = []
    @riichi_tile = -1
  end

  def draw_haipai(tiles)
    @closed_tiles = tiles.sort
    @open_tiles.clear
    @discards.clear
  end

  def draw(tile)
    @closed_tiles.push(tile)
    @closed_tiles.sort!
  end

  def discard(tile)
    @closed_tiles.delete(tile)
    @closed_tiles.sort!
    @discards.push(tile)
  end

  def naki(tiles)
    @tiles.each { |tile|
      @closed_tiles.delete(tile)
      @open_tiles.push(tile)
    }
  end

  def riichi
    @riichi_tile = @discards[-1]
  end

end

#==============================================================================
# ** Game_Hanchan
#==============================================================================

class Game_Hanchan

  def initialize
    @dora = Array.new(-1, 4)
    @players = []
    @states = []
  end

  def refresh
    @players = Array.new(4) { Game_Player.new }
    @states.clear
  end

  def record_current_state
    state = Game_State.new
    state.set_dora(@dora)

    @players.each.with_index { |player, i|
      state.set_discards(i, player.
    }
    state.
    @states.push(state)
  end

  def parse_from_log(log)
    refresh

    log.root.traverse { |node| parse_node(node) }
  end

  def parse_node(node)
    case node.name
    when 'INIT'
      parse_init_node(node)
    when /\A[TUVW]\d+\Z/
      parse_draw_node(node)
    when /\A[DEFG]\d+\Z/
      parse_discard_node(node)
    when 'N'
      parse_naki_node(node)
    when 'REACH'
      parse_riichi_node(node)
    end
  end

  def parse_init_node(node)
    seed = node.attributes["seed"].value.split(',').map { |s| s.to_i }

    @dora.fill(-1)
    @dora[0] = seed[5]

    @players.each.with_index { |player, i|
      haipai = node.attributes["hai#{i}"].value.split(',').map { |s| s.to_i }

      player.draw_haipai(haipai)
    }
  end

  def parse_draw_node(node)
    seat = (node.name[0].ord - 'T'.ord)

    @players[seat].hand.draw(node.name[1..-1].to_i)

    # TODO: Eventually we want this to work for every player.
    record_current_state if seat == 0
  end

  def parse_discard_node(node)
    seat = (node.name[0].ord - 'D'.ord)

    @players[seat].hand.discard(node.name[1..-1].to_i)
  end

  def parse_naki_node(node)
    seat = node.attributes['who'].value.to_i
    naki_tiles = parse_naki_mentsu(node.attributes['m'].to_i)

    @players[seat].hand.naki(naki_tiles)

    # TODO: Eventually we want this to work for every player.
    record_current_state if seat == 0
  end

  def parse_naki_mentsu(m)
    return parse_chi(m) if m & 4
    return parse_pon(m) if m & 8
    return parse_kakan(m) if m & 16
    return parse_kan(m)
  end

  def parse_riichi_node(node)
    return if not node.attributes['step'].value.to_i == 2
    seat = node.attributes['who'].value.to_i

    @players[seat].riichi
  end

end

#==============================================================================
# ** Main
#==============================================================================

hanchan = Game_Hanchan.new()

File.open('replay.log', 'r') { |f|
  hanchan.parse_from_log(Nokogiri::XML(f))
}
