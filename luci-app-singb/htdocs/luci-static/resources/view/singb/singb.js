'use strict';
'require view';
'require form';
'require ui';
'require fs';

return view.extend({
    async render() {
        var m, s, o;

        // Создаем форму
        m = new form.Map('singb', 'Singb Configuration');

        // Добавляем секцию
        s = m.section(form.TypedSection, 'main', 'Control Panel');
        s.anonymous = true;

        // Вкладки
        s.tab('service', _('Service Management'));
        s.tab('config', _('Edit Config'));

        // Вкладка "Service Management"
        o = s.taboption('service', form.DummyValue, 'service_status', _('Service Status'));
        o.rawhtml = true;
        o.cfgvalue = async function () {
            try {
                const result = await fs.exec('/etc/init.d/sing-box', ['status']);
                const status = result.stdout.trim();
                if (status.toLowerCase() === 'running') {
                    return '<span style="color: green; font-weight: bold;">Running</span>';
                } else if (status.toLowerCase() === 'inactive') {
                    return '<span style="color: red; font-weight: bold;">Inactive</span>';
                } else {
                    return `<span style="color: orange;">${status}</span>`;
                }
            } catch (error) {
                return '<span style="color: red;">Error fetching status</span>';
            }
        };

        o = s.taboption('service', form.Button, 'start', _('Start Service'));
        o.inputstyle = 'apply';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['start']);
                ui.addNotification(null, _('Service started.'));
                setTimeout(() => location.reload(), 1000);
            } catch (error) {
                ui.addNotification(null, _('Failed to start service: ') + error.message, 'error');
            }
        };

        o = s.taboption('service', form.Button, 'stop', _('Stop Service'));
        o.inputstyle = 'remove';
        o.onclick = async function () {
            try {
                await fs.exec('/etc/init.d/sing-box', ['stop']);
                ui.addNotification(null, _('Service stopped.'));
                setTimeout(() => location.reload(), 1000);
            } catch (error) {
                ui.addNotification(null, _('Failed to stop service: ') + error.message, 'error');
            }
        };

        // Вкладка "Edit Config"
        const configs = [
            { name: 'config.json', label: _('Main Config') },
            { name: 'config2.json', label: _('Second Config') },
            { name: 'config3.json', label: _('Third Config') }
        ];

        // Добавление редактируемых конфигураций по вкладкам
        configs.forEach((config) => {
            const configTabName = config.name === 'config.json' ? 'main_config' : `config_${config.name}`;
            
            // Создаем вкладку для каждой конфигурации
            s.tab(configTabName, config.label);

            // Поле ввода для конфигурации
            const option = s.taboption(configTabName, form.TextValue, `content_${config.name}`, config.label);
            option.rows = 25;
            option.wrap = 'off';
            option.cfgvalue = async function () {
                try {
                    const content = await fs.read(`/etc/sing-box/${config.name}`);
                    return content || '';
                } catch (error) {
                    return `// Failed to load ${config.name}: ${error.message}`;
                }
            };

            // Сохраняем изменения в конфигурации
            option.write = async function (section_id, value) {
                try {
                    await fs.write(`/etc/sing-box/${config.name}`, value);
                    ui.addNotification(null, `${config.label} saved successfully.`);
                    await fs.exec('/etc/init.d/sing-box', ['restart']);
                    ui.addNotification(null, _('Service restarted.'));
                    setTimeout(() => location.reload(), 1000);
                } catch (error) {
                    ui.addNotification(null, `Failed to save ${config.label}: ` + error.message, 'error');
                }
            };

            // Если это не "Main Config", добавляем кнопку "Set as Main"
            if (config.name !== 'config.json') {
                const setMainButton = s.taboption(configTabName, form.Button, `set_main_${config.name}`, _('Set as Main'));
                setMainButton.inputstyle = 'apply';
                setMainButton.onclick = async function () {
                    try {
                        const mainContent = await fs.read(`/etc/sing-box/${config.name}`);
                        const currentConfigContent = await fs.read('/etc/sing-box/config.json');
                        // Копируем содержимое выбранного файла в config.json
                        await fs.write('/etc/sing-box/config.json', mainContent);
                        // Копируем содержимое config.json в выбранный файл
                        await fs.write(`/etc/sing-box/${config.name}`, currentConfigContent);
                        ui.addNotification(null, `${config.label} is now the main config.`);
                        await fs.exec('/etc/init.d/sing-box', ['restart']);
                        ui.addNotification(null, _('Service restarted.'));
                        setTimeout(() => location.reload(), 1000);
                    } catch (error) {
                        ui.addNotification(null, `Failed to set ${config.label} as the main config: ` + error.message, 'error');
                    }
                };
            }
        });

        // Рендеринг формы
        return m.render();
    },
});
