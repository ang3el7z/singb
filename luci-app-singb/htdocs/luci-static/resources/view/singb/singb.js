'use strict';
'require view';
'require form';
'require ui';
'require fs';

return view.extend({
    async render() {
        var m, s, o;

        // Создаём карту
        m = new form.Map('singb', _('SingBox Plugin'), _('Plugin for managing SingBox service.'));

        // Секция
        s = m.section(form.TypedSection, 'main', _('Settings'));
        s.anonymous = true;

        // Вкладка 1: Control Panel
        s.tab('control', _('Control Panel'));

        // Статус службы
        o = s.taboption('control', form.DummyValue, '_status', _('Service Status'));
        o.cfgvalue = async function () {
            const isRunning = (await fs.exec('/usr/bin/pgrep', ['sing-box'], {})).code === 0;
            return isRunning ? _('Running') : _('Stopped');
        };

        // Кнопка Start
        o = s.taboption('control', form.Button, '_start', _('Start Service'));
        o.inputstyle = 'apply';
        o.onclick = async function () {
            await fs.exec('/etc/init.d/sing-box', ['start'], {});
            ui.addNotification(null, _('Service started.'));
        };

        // Кнопка Stop
        o = s.taboption('control', form.Button, '_stop', _('Stop Service'));
        o.inputstyle = 'remove';
        o.onclick = async function () {
            await fs.exec('/etc/init.d/sing-box', ['stop'], {});
            ui.addNotification(null, _('Service stopped.'));
        };

        // Кнопка Restart
        o = s.taboption('control', form.Button, '_restart', _('Restart Service'));
        o.inputstyle = 'reload';
        o.onclick = async function () {
            await fs.exec('/etc/init.d/sing-box', ['restart'], {});
            ui.addNotification(null, _('Service restarted.'));
        };

        // Вкладка 2: Config
        s.tab('config', _('Config'));

        // Поле для редактирования конфигурации
        o = s.taboption('config', form.TextValue, '_config_data', _('Configuration File'), _('Edit the SingBox configuration file.'));
        o.rows = 20;
        o.cfgvalue = async function () {
            try {
                return await fs.read('/etc/sing-box/config.json');
            } catch (err) {
                return _('Error reading configuration file.');
            }
        };
        o.write = async function (section_id, value) {
            try {
                await fs.write('/etc/sing-box/config.json', value.trim() + '\n');
                ui.addNotification(null, _('Configuration saved.'));
            } catch (err) {
                ui.addNotification(null, _('Error saving configuration: ') + err.message, 'error');
            }
        };

        // Вкладка 3: Placeholder
        s.tab('placeholder', _('Placeholder'));

        o = s.taboption('placeholder', form.DummyValue, '_info', _('Coming Soon'), _('This section is under construction.'));

        return m.render();
    },
});
