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

        // Поле для отображения статуса сервиса
        o = s.option(form.DummyValue, 'service_status', 'Service Status');
        o.rawhtml = true; // Позволяет использовать HTML для стилизации

        // Функция для рендера статуса с цветом
        function renderStatus(status) {
            if (status.toLowerCase() === 'running') {
                return '<span style="color: green; font-weight: bold;">Running</span>';
            } else if (status.toLowerCase() === 'inactive') {
                return '<span style="color: red; font-weight: bold;">Inactive</span>';
            } else {
                return `<span style="color: orange;">${status}</span>`; // Для других статусов
            }
        }

        // Получаем статус сервиса и отображаем его
        o.cfgvalue = async function () {
            try {
                const result = await fs.exec('/etc/init.d/sing-box', ['status']);
                const status = result.stdout.trim();
                return renderStatus(status); // Рендерим статус с цветом
            } catch (error) {
                return '<span style="color: red;">Error fetching status</span>';
            }
        };

        // Кнопка для запуска сервиса
        o = s.option(form.Button, 'start', 'Start Service');
        o.inputstyle = 'apply';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['start']);
                ui.addNotification(null, 'Service started.');
		setTimeout(function() {
            	location.reload();  // Перезагружаем страницу после задержки
       		}, 1000);
            } catch (error) {
                ui.addNotification(null, 'Failed to start service: ' + error.message, 'error');
            }
        };

        // Кнопка для остановки сервиса
        o = s.option(form.Button, 'stop', 'Stop Service');
        o.inputstyle = 'remove';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['stop']);
                ui.addNotification(null, 'Service stopped.');
		setTimeout(function() {
            	location.reload();  // Перезагружаем страницу после задержки
       		}, 1000);
            } catch (error) {
                ui.addNotification(null, 'Failed to stop service: ' + error.message, 'error');
            }
        };

        // Поле для отображения и редактирования config.json
        o = s.option(form.TextValue, 'config_content', 'Config File Content');
        o.rows = 25;
        o.wrap = 'off';

        o.cfgvalue = async function () {
            try {
                const content = await fs.read('/etc/sing-box/config.json');
                return content || ''; // Если файл пустой, вернуть пустую строку
            } catch (error) {
                return '// Failed to load config.json: ' + error.message;
            }
        };

        o.write = async function (section_id, value) {
            try {
                await fs.write('/etc/sing-box/config.json', value);
                ui.addNotification(null, 'Config file saved successfully.');
		await fs.exec('/etc/init.d/sing-box', ['restart']);
		ui.addNotification(null, 'Service restarted.');
		setTimeout(function() {
            	location.reload();  // Перезагружаем страницу после задержки
       		}, 1000);
            } catch (error) {
                ui.addNotification(null, 'Failed to save config file: ' + error.message, 'error');
            }
        };

        return m.render();
    }
});
