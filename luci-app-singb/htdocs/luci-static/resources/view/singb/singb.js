'use strict';
'require view';
'require form';
'require ui';
'require fs';

return view.extend({
    async render() {
        var m, s, o;

        m = new form.Map('singb', 'Singb configuration', null, ['main']);

        s = m.section(form.TypedSection, 'main', 'Control Panel');
        s.anonymous = true;

        // Кнопка для запуска сервиса
        o = s.option(form.Button, 'start', 'Start Service');
        o.inputstyle = 'apply';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['start']);
                ui.addNotification(null, 'Service started.');
            } catch (error) {
                ui.addNotification(null, 'Failed to start service: ' + error.message, 'error');
            }
        };

        // Кнопка для остановки сервиса
        o = s.option(form.Button, 'stop', 'Stop Service');
        o.inputstyle = 'apply';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['stop']);
                ui.addNotification(null, 'Service stopped.');
            } catch (error) {
                ui.addNotification(null, 'Failed to stop service: ' + error.message, 'error');
            }
        };

        // Поле для отображения и редактирования config.json
        o = s.option(form.TextValue, 'config_content', 'Config File Content');
        o.rows = 20;
        o.wrap = 'off';

        // Загрузка содержимого config.json при отображении
        o.cfgvalue = async function () {
            try {
                const content = await fs.read('/etc/sing-box/config.json');
                return content || ''; // Если файл пустой, вернуть пустую строку
            } catch (error) {
                return '// Failed to load config.json: ' + error.message;
            }
        };

        // Сохранение изменений в config.json
        o.write = async function (section_id, value) {
            try {
                await fs.write('/etc/sing-box/config.json', value);
                ui.addNotification(null, 'Config file saved successfully.');
            } catch (error) {
                ui.addNotification(null, 'Failed to save config file: ' + error.message, 'error');
            }
        };

        return m.render();
    }
});
