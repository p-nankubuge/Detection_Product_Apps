# Clean global DI telltale definitions (AND-only)
Paste each block with **Paste Definition from Clipboard**, Validate, Save.

## CHNGE-6771

### 20782 `g-di-dict-neg1-match-short-term-threshold-exceeded`
ST ≥2x, dict -1; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20783 `g-di-dict-neg1-match-long-term-threshold-exceeded`
LT ≥2x, dict -1; requires ST not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6756 `g-di-unknown-signature-exceeding-short-term-threshold`
ST ≥2x and <4x, dict -1; requires LT not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6762 `g-di-unknown-signature-exceeding-4x-short-term-threshold`
ST ≥4x, dict -1; requires LT not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6758 `g-di-unknown-signature-exceeding-long-term-threshold`
LT ≥2x and <4x, dict -1
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6764 `g-di-unknown-signature-exceeding-2x-long-term-threshold`
LT ≥4x, dict -1
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": -1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20775 `g-di-dict-1-match-short-term-threshold-exceeded-1x`
ST ≥2x, dict 1; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20776 `g-di-dict-1-match-short-term-threshold-exceeded-5x`
ST ≥4x, dict 1; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20780 `g-di-dict-1-match-short-term-threshold-exceeded-10x`
ST ≥10x, dict 1; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 9.999, "type": "float"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20781 `g-di-dict-1-match-long-term-threshold-exceeded`
LT ≥2x, dict 1; requires ST not breached; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 1, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

## CHNGE-6773

### 20772 `g-di-dict-3-match-short-term-threshold-exceeded-1x`
ST ≥2x, dict 3; 14 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["F7C0768A-A5B0-422A-BC5F-5912456296EE", "0F985541-B543-4B29-A098-4BB9B8E9DEF8", "F5675B21-025B-4843-983C-38D86DEB394B", "7CC24C4A-611B-41C7-9808-B95722C7861C", "E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF", "56DA9CC0-3C2D-47A7-A8C0-564572D4D008", "EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "825DD2FA-D899-455F-970A-9E2453663EEA", "26AA6D55-8C04-4BD7-8A71-F66E707C8C42", "4FDBF9EF-B787-48E4-8891-F065A8076184", "42887D34-B283-4723-AD25-26299EB55AC9", "E8A64FAC-C713-4EB4-85D2-7458E3579D31", "519C70B3-B8F5-427B-827F-D2D54AB25D04", "54B78A70-0DD3-455D-BA99-AB5CB14276CF"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 3, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20773 `g-di-dict-3-match-short-term-threshold-exceeded-4x`
ST ≥4x, dict 3; 14 keys excluded; keeps 1 OR group: Brave missing OR false (only real OR)
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["F7C0768A-A5B0-422A-BC5F-5912456296EE", "0F985541-B543-4B29-A098-4BB9B8E9DEF8", "F5675B21-025B-4843-983C-38D86DEB394B", "7CC24C4A-611B-41C7-9808-B95722C7861C", "E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF", "56DA9CC0-3C2D-47A7-A8C0-564572D4D008", "EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "825DD2FA-D899-455F-970A-9E2453663EEA", "26AA6D55-8C04-4BD7-8A71-F66E707C8C42", "4FDBF9EF-B787-48E4-8891-F065A8076184", "42887D34-B283-4723-AD25-26299EB55AC9", "E8A64FAC-C713-4EB4-85D2-7458E3579D31", "519C70B3-B8F5-427B-827F-D2D54AB25D04", "54B78A70-0DD3-455D-BA99-AB5CB14276CF"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 3, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"operator": "OR", "conditions": [{"key": "browser_detection_brave", "operator": "NOT_EXISTS"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}]}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20774 `g-di-dict-3-match-long-term-threshold-exceeded`
LT ≥2x, dict 3; requires ST not breached; 14 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["F7C0768A-A5B0-422A-BC5F-5912456296EE", "0F985541-B543-4B29-A098-4BB9B8E9DEF8", "F5675B21-025B-4843-983C-38D86DEB394B", "7CC24C4A-611B-41C7-9808-B95722C7861C", "E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF", "56DA9CC0-3C2D-47A7-A8C0-564572D4D008", "EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "825DD2FA-D899-455F-970A-9E2453663EEA", "26AA6D55-8C04-4BD7-8A71-F66E707C8C42", "4FDBF9EF-B787-48E4-8891-F065A8076184", "42887D34-B283-4723-AD25-26299EB55AC9", "E8A64FAC-C713-4EB4-85D2-7458E3579D31", "519C70B3-B8F5-427B-827F-D2D54AB25D04", "54B78A70-0DD3-455D-BA99-AB5CB14276CF"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 3, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

## CHNGE-6772

### 20768 `g-di-dict-7-match-short-term-threshold-exceeded-1x`
ST ≥2x, dict 7; 3 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "F5675B21-025B-4843-983C-38D86DEB394B", "E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 7, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20769 `g-di-dict-7-match-short-term-threshold-exceeded-4x`
ST ≥4x, dict 7; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 7, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20771 `g-di-dict-7-match-long-term-threshold-exceeded`
LT ≥2x, dict 7; requires ST not breached; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 7, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20765 `g-di-dict-15-match-short-term-threshold-exceeded-1x`
ST ≥2x, dict 15; 2 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "ua", "operator": "TS_NOT_CONTAINS", "value": "RingApp", "type": "string"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20767 `g-di-dict-15-match-short-term-threshold-exceeded-4x`
ST ≥4x, dict 15; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "ua", "operator": "TS_NOT_CONTAINS", "value": "RingApp", "type": "string"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20758 `g-di-dict-15-match-long-term-threshold-exceeded`
LT ≥2x, dict 15; requires ST not breached; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["E8A64FAC-C713-4EB4-85D2-7458E3579D31"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "ua", "operator": "TS_NOT_CONTAINS", "value": "RingApp", "type": "string"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20751 `g-di-dict-31-match-short-term-threshold-exceeded-1x`
ST ≥2x, dict 31
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 31, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20756 `g-di-dict-31-match-short-term-threshold-exceeded-4x`
ST ≥4x, dict 31
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 31, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 20757 `g-di-dict-31-match-long-term-threshold-exceeded`
LT ≥2x, dict 31
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 31, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

## CHNGE-6797

### 6755 `g-di-high-risk-signature-exceeding-short-term-threshold`
ST ≥2x and <4x, dict [7, 3]; requires LT not breached; 2 keys excluded; keeps 1 OR group: Brave missing OR false (only real OR)
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "F5675B21-025B-4843-983C-38D86DEB394B"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_IN", "value": [7, 3], "type": "list[int]"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"operator": "OR", "conditions": [{"key": "browser_detection_brave", "operator": "NOT_EXISTS"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}]}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6761 `g-di-high-risk-signature-exceeding-4x-short-term-threshold`
ST ≥4x, dict [7, 3]; requires LT not breached; 1 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["F5675B21-025B-4843-983C-38D86DEB394B"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_IN", "value": [7, 3], "type": "list[int]"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "browser_name", "operator": "TS_NOT_EQ", "value": "Samsung Browser", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6759 `g-di-high-risk-signature-exceeding-long-term-threshold`
LT ≥2x and <4x, dict [7, 3]; 2 keys excluded; keeps 1 OR group: Brave missing OR false (only real OR)
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "F5675B21-025B-4843-983C-38D86DEB394B"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_IN", "value": [7, 3], "type": "list[int]"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"operator": "OR", "conditions": [{"key": "browser_detection_brave", "operator": "NOT_EXISTS"}, {"key": "browser_detection_brave", "operator": "TS_EQ", "value": false, "type": "boolean"}]}, {"key": "browser_name", "operator": "TS_NOT_EQ", "value": "Samsung Browser", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6766 `g-di-high-risk-signature-exceeding-2x-long-term-threshold`
LT ≥4x, dict [7, 3]; 2 keys excluded
```json
[{"key": "public_key", "operator": "TS_NOT_IN", "value": ["EE844FC3-499D-4A4D-A643-D7400F0FD4DE", "F5675B21-025B-4843-983C-38D86DEB394B"], "type": "list[string]"}, {"key": "di_dictionary_num_matched", "operator": "TS_IN", "value": [7, 3], "type": "list[int]"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "browser_name", "operator": "TS_NOT_EQ", "value": "Samsung Browser", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6754 `g-di-medium-risk-signature-exceeding-short-term-threshold`
ST ≥2x and <4x, dict 15; requires LT not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6760 `g-di-medium-risk-signature-exceeding-4x-short-term-threshold`
ST ≥4x, dict 15; requires LT not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_short_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6757 `g-di-medium-risk-signature-exceeding-long-term-threshold`
LT ≥2x and <4x, dict 15; requires ST not breached
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_short_term_threshold_breached", "operator": "TS_EQ", "value": false, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 1.999, "type": "float"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_LESS", "value": 4.0, "type": "float"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```

### 6763 `g-di-medium-risk-signature-exceeding-2x-long-term-threshold`
LT ≥4x, dict 15
```json
[{"key": "di_dictionary_num_matched", "operator": "TS_EQ", "value": 15, "type": "int"}, {"key": "di_called", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_success", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_is_suspicious", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_breached", "operator": "TS_EQ", "value": true, "type": "boolean"}, {"key": "di_long_term_threshold_ratio", "operator": "TS_GREATER", "value": 3.999, "type": "float"}, {"key": "location", "operator": "TS_EQ", "value": "session_setup", "type": "string"}, {"operator": "#INCLUDE", "value": "g-global-telltales-enabled"}]
```
