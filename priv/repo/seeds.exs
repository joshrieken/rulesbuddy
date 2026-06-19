alias RulesBuddy.Repo
alias RulesBuddy.Users.User
alias RulesBuddy.Games.Game

# --- Admin User ---

username = "admin"
email = "admin@rulesbuddy.local"
password = "admin"

if is_nil(Repo.get_by(User, username: username)) do
  Repo.insert!(
    User.registration_changeset(%User{}, %{
      username: username,
      email: email,
      password: password,
      role: "game_master"
    })
  )

  IO.puts("Seeded game_master user: #{username} / #{password}")
else
  IO.puts("game_master user already exists: #{username}")
end

# --- Sample Games ---

sample_games = [
  %{
    name: "Carcassonne",
    bgg_id: 822,
    sources: [
      %{
        label: "Core Rules",
        full_text: """
        CARCASSONNE — RULES SUMMARY

        Object of the Game:
        Place tiles to build a medieval landscape of cities, roads, monasteries, and fields. Deploy your followers (meeples) as thieves, knights, monks, or farmers to score points.

        Setup:
        Place the starting tile face-up in the center of the table. Shuffle the remaining tiles face-down in several stacks within reach of all players. Each player takes 8 meeples in their color (7 regular + 1 scoring meeple). The youngest player goes first.

        On Your Turn (3 steps):
        1. DRAW AND PLACE A TILE: Draw 1 tile from any face-down stack. Place it adjacent to at least one already-placed tile. The tile must continue all existing edges (road must connect to road, city to city, field to field).
        2. DEPLOY A FOLLOWER: You may place 1 meeple from your supply onto the tile you just placed, on a feature that is not yet occupied.
        3. SCORE COMPLETED FEATURES: If placing the tile completes any city, road, or monastery, score those features immediately and return the meeples to their owners.

        Scoring:

        ROADS: A road is complete when its ends are closed (by a village, crossroads, city, monastery, or the road looping back on itself). Each tile in the road scores 1 point. The player with a thief on the road scores the points.

        CITIES: A city is complete when it is surrounded by walls with no gaps. Each tile in the city scores 2 points. Each coat of arms (shield icon) in the city scores 2 extra points. The player with a knight in the city scores the points.

        MONASTERIES: A monastery is complete when it is surrounded by 8 tiles (or the edge of the playing area). Scores 9 points (1 for the monastery tile + 1 for each surrounding tile).

        FIELDS (scored at end of game): Farmers are scored at the end. For each completed city adjacent to a field, the player with the most farmers in that field scores 3 points.

        RULES FOR FOLLOWERS:
        - You may only place one follower per turn.
        - You cannot place a follower on a feature that already has a follower (yours or an opponent's).
        - When a completed feature scores, the meeples on it return to their owners' supply.
        - A player may have multiple followers on the same feature only if they were placed on different tiles as separate features that later merged.

        FARMERS:
        A farmer is placed lying down in a field. Farmers stay on the board for the entire game and are scored at the end. Farmers in a field score 3 points for each completed city that borders that field. If multiple players have farmers in the same field, only the player with the most farmers scores (tie = both score).

        End of Game:
        The game ends when the last tile has been placed. Final scoring: incomplete cities score 1 point per tile + 1 per coat of arms. Incomplete roads score 1 point per tile. Incomplete monasteries score 1 point for the monastery tile + 1 for each adjacent tile. Fields are scored as described above.

        The player with the most points wins.
        """
      }
    ]
  },
  %{
    name: "Catan",
    bgg_id: 13,
    sources: [
      %{
        label: "Core Rules",
        full_text: """
        CATAN — RULES SUMMARY

        Object of the Game:
        Be the first player to reach 10 victory points. Points are earned by building settlements, upgrading to cities, having the longest road, the largest army, and holding special victory point cards.

        Setup:
        The board is made of 19 hexagonal tiles arranged randomly. Each tile produces a resource (Brick, Lumber, Wool, Grain, Ore). Number tokens (2-12) are placed on each resource tile. The desert tile produces nothing and has no number token. Each player places 2 settlements (each worth 1 VP) and 2 roads at the start. Place the robber on the desert tile. Shuffle the development cards.

        On Your Turn (4 phases):
        1. ROLL: Roll both dice. The sum determines which tiles produce resources. Any player with a settlement adjacent to a tile matching the roll receives 1 resource of that type. A city on that tile receives 2 resources.
        2. TRADE: You may trade resources with other players or use the maritime trade ratios (4:1 with the bank, 3:1 at a port, 2:1 at a specific resource port).
        3. BUILD: Spend resources to build:
           - Road (1 Brick + 1 Lumber): 0 VP, extends your network
           - Settlement (1 Brick + 1 Lumber + 1 Wool + 1 Grain): 1 VP
           - City (3 Ore + 2 Grain): 2 VP (upgrades a settlement)
           - Development Card (1 Ore + 1 Wool + 1 Grain): varies
        4. (Optional) Play a development card (may only play 1 per turn, not the same turn you bought it).

        THE ROBBER:
        When a 7 is rolled, every player with more than 7 resource cards must discard half (rounded down). Then the active player moves the robber to any tile and steals 1 random resource card from a player with a settlement/city adjacent to that tile. While the robber is on a tile, that tile produces no resources.

        DEVELOPMENT CARDS:
        - Knight (14 cards): Move the robber. May also count toward the Largest Army (3 VP) if you have played 3+ knights.
        - Victory Point (5 cards): Worth 1 VP. Play immediately.
        - Road Building (2 cards): Place 2 free roads.
        - Year of Plenty (2 cards): Take any 2 resources from the bank.
        - Monopoly (2 cards): All players give you all cards of the resource you name.

        SPECIAL AWARDS:
        - Longest Road: 2 VP for the player with the longest continuous road (5+ segments).
        - Largest Army: 2 VP for the player who has played 3+ Knight cards (most knights wins).

        End of Game:
        The game ends immediately when a player reaches 10 victory points on their turn. The player with 10+ VP wins.
        """
      }
    ]
  }
]

for game_attrs <- sample_games do
  if is_nil(Repo.get_by(Game, name: game_attrs.name)) do
    {:ok, game} =
      RulesBuddy.Games.create_game(%{name: game_attrs.name, bgg_id: game_attrs.bgg_id})

    for source_attrs <- game_attrs.sources do
      RulesBuddy.Games.create_rulebook_source(%{
        game_id: game.id,
        label: source_attrs.label,
        full_text: String.trim(source_attrs.full_text)
      })
    end

    IO.puts("Seeded game: #{game_attrs.name}")
  else
    IO.puts("Game already exists: #{game_attrs.name}")
  end
end

IO.puts("\nSeeds complete! Log in at http://localhost:4000/login with admin / admin")
