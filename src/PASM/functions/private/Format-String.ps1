function Format-String {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ValidateSet("Center","Left","Right","Justify","JustifyChars")]
        [string]$Format = "Center",

        [Parameter(Mandatory)]
        [int]$OutputStringWidth,

        [string]$PadChar = " "
    )

    # Early return if text is already long enough
    if ($Text.Length -ge $OutputStringWidth) {
        return $Text
    }

    switch ($Format) {

        "Center" {
            $total = $OutputStringWidth - $Text.Length
            $left  = [math]::Floor($total / 2)
            $right = $total - $left
            return ($PadChar * $left) + $Text + ($PadChar * $right)
        }

        "Left" {
            return $Text + ($PadChar * ($OutputStringWidth - $Text.Length))
        }

        "Right" {
            return ($PadChar * ($OutputStringWidth - $Text.Length)) + $Text
        }

        "Justify" {
            $words = $Text -split '\s+'

            # Only one word → left align
            if ($words.Count -eq 1) {
                return $Text + ($PadChar * ($OutputStringWidth - $Text.Length))
            }

            $totalChars = ($words | Measure-Object Length -Sum).Sum
            $spaces     = $OutputStringWidth - $totalChars
            $gaps       = $words.Count - 1

            $base  = [math]::Floor($spaces / $gaps)
            $extra = $spaces % $gaps

            $result = ""
            for ($i = 0; $i -lt $words.Count; $i++) {
                $result += $words[$i]
                if ($i -lt $gaps) {
                    $gapSize = $base + ([int]($i -lt $extra))
                    $result += ($PadChar * $gapSize)
                }
            }
            return $result
        }

        "JustifyChars" {
            $chars = $Text.ToCharArray()
            $count = $chars.Count
            $spaces = $OutputStringWidth - $count
            $gaps = $count - 1

            # Only one char → left align
            if ($gaps -eq 0) {
                return $chars[0] + ($PadChar * $spaces)
            }

            $base  = [math]::Floor($spaces / $gaps)
            $extra = $spaces % $gaps

            $result = ""
            for ($i = 0; $i -lt $count; $i++) {
                $result += $chars[$i]
                if ($i -lt $gaps) {
                    $gapSize = $base + ([int]($i -lt $extra))
                    $result += ($PadChar * $gapSize)
                }
            }
            return $result
        }
    }
}
