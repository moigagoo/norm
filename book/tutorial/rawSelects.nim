import nimib, nimibook


nbInit(theme = useNimibook)

nbText: """
# Raw SQL SELECT interactions

Sometimes SQL abilities are needed that Norm can not represent well.

For such cases, Norm provides a way to execute raw SQL SELECT queries and parse the received data into a user provided ``ref object`` type.
This bypassses Norm's ability to generate the SQL for you, but still allows you to use Norm's ability parse ``Row`` instances.
"""

nbCode:
  import std/json
  import norm/[model, sqlite, pragmas]

  type Campaign* = ref object of Model
      name* {.unique.}: string

  type Creature* = ref object of Model
      name*: string
      campaign* {.fk: Campaign.}: int64

  putEnv("DB_HOST", ":memory:")
  let db = getDb()
  db.createTables(Campaign())
  db.createTables(Creature())

  # Add entries to Db
  var campaign = Campaign(name: "MyCampaign")
  db.insert(campaign)

  var creature1 = Creature(name: "creature1", campaign: campaign.id)
  var creature2 = Creature(name: "creature2", campaign: campaign.id)
  db.insert(creature1)
  db.insert(creature2)

  # Query DB
  type CreatureCampaignCount* = ref object
    count*: int

  let countCampaignCreaturesQuery: string = """
    SELECT COUNT(*) AS count
    FROM creature
    INNER JOIN campaign ON creature.campaign = campaign.id
    WHERE campaign.name = ?
  """

  var countResult = CreatureCampaignCount()
  db.rawSelect(countCampaignCreaturesQuery, countResult, campaign.name)

  echo countResult.count

nbSave
