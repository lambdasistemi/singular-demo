Bob owes money to Alice and to Dave, and he does not know where either of them receives it. Here he pays them **by name**. The names are in a registry on Cardano that Carol made and published: anyone can put a name in it, and the person who does is the name's controller. Bob pays the name, the money waits in a script that reads the registry, and whoever moves it can only send it to the address that is registered under the name at that moment.

You play all five of them on a **private test chain**: nothing touches a public network, and nothing is installed on this machine beyond tmux. The project is at https://github.com/lambdasistemi/singular and its documentation at https://lambdasistemi.github.io/singular/ . Each person has a tmux window of their own, and you switch between them by clicking a word: `carol`, `alice`, `dave`, `bob` or `chain`. You will, step by step:

- make five wallets and start the chain,
- let Carol create and publish the registry, and let Alice, Bob and Dave each check it,
- let Alice and Dave put their names in it, and let Bob ask for them,
- let Bob pay both names, and let Alice and Dave move their money,
- let Alice change her address, and see a move to the old one refused.

Every command is shown in full with what it does. Click a command to run it, read what comes back, and go on.

The machine lasts one hour at most and is deleted when you close this tab. The whole journey takes about 20 minutes. If the chain on the machine is ever stopped, restart the scenario: a new machine starts from the beginning.

A kit with the programs, node included, and tmux are being installed in the background. When the terminal says `Ready`, start.
