return {
    --集群
    cluster = {
        node1 = "0.0.0.0:13335",
        node2 = "0.0.0.0:13336",
    },
    --agentmgr
    agentmgr = { node = "node1" },
    --scene
    scene = {
        node1 = { 1001 },
        --node2 = {1003},
    },
    --节点1
    node1 = {
        gateway = {
            [1] = { port = 12333 },
            [2] = { port = 12334 },
        },
        login = {
            [1] = {},
            [2] = {},
        },
    },

    --节点2
    node2 = {
        gateway = {
            [1] = { port = 12211 },
            [2] = { port = 12212 },
        },
        login = {
            [1] = {},
            [2] = {},
        },
    },
}
