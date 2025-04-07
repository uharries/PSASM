[![](https://mermaid.ink/img/pako:eNp9kl1PwjAUhv_KPJdmkG1udPTCRMFEE1AjNxvWi8oqLNKOdJ0BCf_dMrdRGGFXPed9-p6PdQuzLGGAIVdUsWFK55Lyzo9HBBHv1x9Wp3Nr3X3m2bJQzMLW1eiVSmZoT5yzJKWl-EjzhaGIJJVsprRQXyKisSp97ydafHgZnearQDuwNUs0M8g4pweqFs7AkaajFhlV9aLTehecYs3GLTKunOLaiYhmUHNqY2dv1fQtqeSfh7XTeb1KtnZxKpyBqwla2RKdXpigVcmsYGz5aLt1YPx3Y_Jj6b-DyOigeUalNB6DDZxJTtNEv80tEZZFQC0YZwSwPiZUfhMgYqc5WqhsshEzwEoWzAaZFfMF4C-6zHVUrJLDw66RFRXTLGvCudyXqS7ojhMmB1khFGD3poQBb2GtI9fp-r3ACVHYd3peYMMGMPK6ruf3EXJdN3R7_s6G39Lb6YYocPYfQj4KkLv7Awr4Hfg?type=png)](https://mermaid.live/edit#pako:eNp9kl1PwjAUhv_KPJdmkG1udPTCRMFEE1AjNxvWi8oqLNKOdJ0BCf_dMrdRGGFXPed9-p6PdQuzLGGAIVdUsWFK55Lyzo9HBBHv1x9Wp3Nr3X3m2bJQzMLW1eiVSmZoT5yzJKWl-EjzhaGIJJVsprRQXyKisSp97ydafHgZnearQDuwNUs0M8g4pweqFs7AkaajFhlV9aLTehecYs3GLTKunOLaiYhmUHNqY2dv1fQtqeSfh7XTeb1KtnZxKpyBqwla2RKdXpigVcmsYGz5aLt1YPx3Y_Jj6b-DyOigeUalNB6DDZxJTtNEv80tEZZFQC0YZwSwPiZUfhMgYqc5WqhsshEzwEoWzAaZFfMF4C-6zHVUrJLDw66RFRXTLGvCudyXqS7ojhMmB1khFGD3poQBb2GtI9fp-r3ACVHYd3peYMMGMPK6ruf3EXJdN3R7_s6G39Lb6YYocPYfQj4KkLv7Awr4Hfg)

stateDiagram-v2
```
[*] --> Absolute : !LParen
[*] --> Immediate : Hash
[*] --> Indirect : LParen

Absolute --> ABS : EOL
Absolute --> AbsoluteIndexed : Comma
AbsoluteIndexed --> AbsoluteIndexedX : X
AbsoluteIndexedX --> ABX : EOL
AbsoluteIndexed --> AbsoluteIndexedY : Y
AbsoluteIndexedY --> ABY : EOL

Indirect --> IndirectAbsolute : RParen
IndirectAbsolute --> IND : EOL
IndirectAbsolute --> IndirectIndexed : Comma
IndirectIndexed --> IndirectIndexedY : Y
IndirectIndexedY --> IZY : EOL

Indirect --> Indexed : Comma
Indexed --> IndexedX : X
IndexedX --> IndexedXIndirect : RParen
IndexedXIndirect --> IZX : EOL

Immediate --> IMM
```

![](mermaid-diagram-2025-04-06-152454.png)
