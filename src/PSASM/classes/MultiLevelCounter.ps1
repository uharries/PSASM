class MultiLevelCounter {
    [int[]] $Counters
    [System.Collections.Stack] $History
    [int] $HighestSavedLevel = -1

    MultiLevelCounter([int]$levels) {
        $this.Counters = @(0) * $levels
        $this.History = [System.Collections.Stack]::new()
    }

    [void] Inc([int]$idx) {
        if ($idx -lt 0 -or $idx -ge $this.Counters.Count) {
            throw "Invalid counter index: $idx"
        }

        # Save history only when incrementing a higher-level counter
        if ($idx -lt $this.HighestSavedLevel -or $this.HighestSavedLevel -eq -1) {
            $this.History.Push(@($this.Counters))
            $this.HighestSavedLevel = $idx
        }

        # Increment the selected counter
        $this.Counters[$idx]++

        # Reset all lower counters
        for ($i = $idx + 1; $i -lt $this.Counters.Count; $i++) {
            $this.Counters[$i] = 0
        }
    }

    [void] Dec([int]$idx) {
        if ($idx -lt 0 -or $idx -ge $this.Counters.Count) {
            throw "Invalid counter index: $idx"
        }

        $this.Counters[$idx]--

        if ($this.Counters[$idx] -lt 0) {
            # Underflow – restore previous saved state if any
            if ($this.History.Count -gt 0) {
                $this.Counters = @($this.History.Pop())
                # Update highest saved level if possible
                if ($this.History.Count -gt 0) {
                    $peek = $this.History.Peek()
                    $this.HighestSavedLevel = ($peek.Count - 1) - ($peek | ForEach-Object {$_})[-1]
                } else {
                    $this.HighestSavedLevel = -1
                }
            }
            else {
                # Nothing to restore, clamp to zero
                $this.Counters = @(0) * $this.Counters.Count
                $this.HighestSavedLevel = -1
            }
        }
    }

    [void] IncLast() { $this.Inc($this.Counters.Count - 1) }
    [void] DecLast() { $this.Dec($this.Counters.Count - 1) }

    [string] ToString() {
        return 'Counters = [' + ($this.Counters -join ', ') + ']'
    }
}
