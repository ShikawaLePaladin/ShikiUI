-- mock_bind.lua : GetMouseFocus et GetBindingAction simules pour le service de raccourcis (Bind.lua).
-- Les raccourcis eux-memes vivent dans W.ab.bind (voir mock_actionbars.lua : SetBinding, GetBindingKey, SaveBindings).
-- Aides : SETFOCUS(frame) = le curseur survole ce frame. Les valeurs sont des DONNEES DE TEST.
W = W or {}
W.bind = { focus = nil }

GetMouseFocus = function() return W.bind.focus end
GetBindingAction = function(key)
  for cmd, b in pairs(W.ab.bind) do
    if b[1] == key or b[2] == key then return cmd end
  end
  return ""
end
function SETFOCUS(f) W.bind.focus = f end
