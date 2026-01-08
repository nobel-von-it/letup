-- themes/melancholy/colors/melancholy.lua
-- Сбрасываем кэш модуля, чтобы можно было перезагружать тему на лету
package.loaded["melancholy"] = nil
package.loaded["melancholy.palette"] = nil
package.loaded["melancholy.groups"] = nil

-- Запускаем нашу тему
require("melancholy").setup()
