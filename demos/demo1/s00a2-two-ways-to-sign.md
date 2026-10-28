# Before you start: two ways to sign

A vault is an encrypted key file. Most commands in Demo1 use the actor's own vault to build, sign and submit a transaction, then wait for its confirmation. Each actor keeps their vault, settings, journal and receipts in their own directory.

Bob also uses external signing: the application command builds an unsigned bundle, `singular wallet sign` writes its witnesses, then `singular submit` sends it and waits for confirmation. The unsigned builder returns exit status 19, meaning waiting for signatures. Building and signing alone send nothing to the chain.
