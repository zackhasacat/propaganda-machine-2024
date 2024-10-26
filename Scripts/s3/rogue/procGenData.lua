local SCALE_FACTOR = 3
local TRANSITION_SIZE = 512 * SCALE_FACTOR
local ROOM_SIZE = 2048 * SCALE_FACTOR
local CHUNK_SIZE = TRANSITION_SIZE + ROOM_SIZE

return {
  SCALE_FACTOR = SCALE_FACTOR,
  TRANSITION_SIZE = TRANSITION_SIZE,
  ROOM_SIZE = ROOM_SIZE,
  CHUNK_SIZE = CHUNK_SIZE,
  templateCells = {
    {
      cellId = "pd_twisty",
      edges = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = true,
        ["west"] = true
      },
      barriers = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
    },
    {
      cellId = "pd_twisty_alt",
      edges = {
        ["north"] = true,
        ["south"] = true,
        ["east"] = false,
        ["west"] = false
      },
      barriers = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
    },
    {
      cellId = "pd_shaft",
      edges = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
      barriers = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
    },
    {
      cellId = "pd_labyrinth",
      edges = {
        ["north"] = true,
        ["south"] = true,
        ["east"] = true,
        ["west"] = true
      },
      barriers = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
    },
    {
      cellId = "claustro",
      edges = {
        ["north"] = true,
        ["south"] = true,
        ["east"] = true,
        ["west"] = true
      },
      barriers = {
        ["north"] = true,
        ["south"] = true,
        ["east"] = true,
        ["west"] = true
      },
    },
    {
      cellId = "pd_zen",
      edges = {
        ["north"] = true,
        ["south"] = true,
        ["east"] = true,
        ["west"] = true
      },
      barriers = {
        ["north"] = false,
        ["south"] = false,
        ["east"] = false,
        ["west"] = false
      },
    },
  },

  transitions = {
    vertical = {
      "pd_connector_ns_1",
      "pd_connector_ns_2",
    },

    horizontal = {
      "pd_connector_ew_1",
      "pd_connector_ew_2",
    },
  },

  edges = {
    east = {
      "pd-edge-east",
    },
    west = {
      "pd-edge-west",
    },
    north = {
      "pd-edge-north",
    },
    south = {
      "pd-edge-south",
    },
  },

  edgeBarriers = {
    "pd-barrier-1",
    "pd-barrier-2",
    "pd-barrier-3",
    "pd-barrier-4",
  },

  enemyLists = {
    easy = {
      "PD_DagonUrul-2",
      "PD_HelnimFieldsCave-2",
      "PD_MolagreahdCave-2",
    },
    medium = {
      "PD_DagonUrul+0",
      "PD_HelnimFieldsCave+0",
      "PD_MolagreahdCave+0",
    },
    hard = {
      "PD_DagonUrul+2",
      "PD_HelnimFieldsCave+2",
      "PD_MolagreahdCave+2",
    },
  },
}
