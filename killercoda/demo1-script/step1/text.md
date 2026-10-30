Run the annotated script. It starts a private test chain, creates three wallets, and plays all 16 steps of Demo 1. Straight through, it takes about 5 minutes, two of them real waits on the chain (the registry's windows are set to 60 and 30 seconds here). Choose one of the two ways to run it.

**Straight through.** The script runs in the background and writes everything to a log, and the terminal follows the log. So pressing Ctrl+C, or copying text with it, only stops the following: the demo carries on.

```bash
cd /home/singular-demo/singular-demo-v0.19.0-1-x86_64-linux && (runuser -u singular-demo -- env DEMO_MODE=continuous PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 setsid nohup ./demo.sh > demo.log 2>&1 &) ; sleep 1; tail -n +1 -f demo.log
```{{exec}}

To copy text from the terminal, select it and use Ctrl+Shift+C, or right-click.

If you stopped following, pick the log up again from the start:

```bash
tail -n +1 -f /home/singular-demo/singular-demo-v0.19.0-1-x86_64-linux/demo.log
```{{exec}}

When the log ends with the last step, the run is over and the chain it started has been stopped.

**Pausing before each step.** The script runs in the foreground in this terminal. Before each step it says what the step does and waits for Enter. Steps 4, 13 and 16 run without a pause, because a booking must be folded before its processing deadline. Here Ctrl+C stops the run.

```bash
cd /home/singular-demo/singular-demo-v0.19.0-1-x86_64-linux && runuser -u singular-demo -- env DEMO_MODE=pause PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 ./demo.sh
```{{exec}}

Run one of the two: a second run in the same folder is refused, because its wallets belong to the first chain. The script asks for no passphrase; the wallets use throwaway passphrases.
