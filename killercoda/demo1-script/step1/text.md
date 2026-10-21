Run the annotated script. It starts a private test chain, creates two wallets, and plays all 16 steps of Demo 1, explaining each one as it goes. It takes about 5 minutes, two of them real waits on the chain (the registry's windows are set to 60 and 30 seconds here).

The script runs in the background and writes everything to a log, and the terminal follows the log. So pressing Ctrl+C, or copying text with it, only stops the following: the demo carries on.

```bash
cd ~/singular-demo-v0.14.0-x86_64-linux && (PROCESS_TIME_MS=60000 RETRACT_TIME_MS=30000 setsid nohup ./demo.sh > demo.log 2>&1 &) ; sleep 1; tail -n +1 -f demo.log
```{{exec}}

To copy text from the terminal, select it and use Ctrl+Shift+C, or right-click.

If you stopped following, pick the log up again from the start:

```bash
tail -n +1 -f ~/singular-demo-v0.14.0-x86_64-linux/demo.log
```{{exec}}

The script asks nothing; the wallets use throwaway passphrases. When the log ends with the last step, the run is over and the chain it started has been stopped.
