return {
    --集群
    cluster = {
        node1 = "0.0.0.0:13031",
        node2 = "0.0.0.0:13032",
    },
    --agentmgr
    agentmgr = { node = "node1" },
    --scene
    scene = {
        node1 = { 1001, 1002 },
        --node2 = {1003},
    },
    --节点1
    node1 = {
        gateway = {
            [1] = { port = 12111 },
            [2] = { port = 8889 },
        },
        login = {
            [1] = {},
            [2] = {},
        },
    },

    --节点2
    node2 = {
        gateway = {
            [1] = { port = 12111 },
            [2] = { port = 12112 },
        },
        login = {
            [1] = {},
            [2] = {},
        },
    },
}
