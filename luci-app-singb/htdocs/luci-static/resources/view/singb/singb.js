'use strict';
'require view';
'require form';
'require ui';
'require fs';

return view.extend({
    async render() {
        let m, s, o;

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
                const status = result.stdout.trim().toLowerCase();
                if (status === 'running') {
                    return '<span style="color: green; font-weight: bold;">Running</span>';
                } else if (status === 'inactive') {
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
            { name: 'config.json',  label: _('Main Config')   },
            { name: 'config2.json', label: _('Second Config') },
            { name: 'config3.json', label: _('Third Config')  }
        ];

        configs.forEach((config) => {
            const tabName = config.name === 'config.json'
                ? 'main_config'
                : `config_${config.name}`;

            // Создаем вкладку для каждой конфигурации
            s.tab(tabName, config.label);

            // Поле для URL подписки
            const urlKey = `subscribe_url_${config.name}`;
            o = s.taboption(tabName, form.Value, urlKey, _('Subscribe URL'));
            o.datatype = 'url';
            o.placeholder = 'https://example.com/subscribe';
            o.cfgvalue = async function () {
                try {
                    return await fs.read(`/etc/sing-box/url_${config.name}`) || '';
                } catch {
                    return '';
                }
            };
            o.write = async function (_, value) {
                await fs.write(`/etc/sing-box/url_${config.name}`, value.trim());
            };

            // Кнопка Update
            o = s.taboption(tabName, form.Button, `update_${config.name}`, _('Update Config'));
            o.inputtitle = _('Update from URL');
            o.inputstyle = 'reload';
            o.onclick = async function () {
                try {
                    const urlPath    = `/etc/sing-box/url_${config.name}`;
                    const targetFile = `/etc/sing-box/${config.name}`;
                    const url        = (await fs.read(urlPath)).trim();

                    if (!url) {
                        throw new Error('URL is empty');
                    }

                    const result = await fs.exec('/usr/bin/singb-updater', [urlPath, targetFile]);
                    if (result.code !== 0) {
                        const details = result.stderr || result.stdout || 'Unknown error';
                        throw new Error(`Update failed: ${details}`);
                    }

                    if (config.name === 'config.json') {
                        await fs.exec('/etc/init.d/sing-box', ['restart']);
                        ui.addNotification(null, _('Service restarted.'));
                    }

                    setTimeout(() => location.reload(), 500);
                } catch (e) {
                    ui.addNotification(null, _('Error: ') + e.message, 'error');
                }
            };

            // Поле редактирования контента конфигурации
            const contentKey = `content_${config.name}`;
            o = s.taboption(tabName, form.TextValue, contentKey, config.label);
            o.rows = 25;
            o.wrap = 'off';
            o.cfgvalue = async function () {
                try {
                    return (await fs.read(`/etc/sing-box/${config.name}`)) || '';
                } catch (error) {
                    return `// Failed to load ${config.name}: ${error.message}`;
                }
            };
            o.write = async function (_, value) {
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

            // Кнопка "Set as Main" для дополнительных конфигов
            if (config.name !== 'config.json') {
                const btn = s.taboption(tabName, form.Button, `set_main_${config.name}`, _('Set as Main'));
                btn.inputstyle = 'apply';
                btn.onclick = async function () {
                    try {
                        const newMain = await fs.read(`/etc/sing-box/${config.name}`);
                        const oldMain = await fs.read('/etc/sing-box/config.json');

                        await fs.write('/etc/sing-box/config.json', newMain);
                        await fs.write(`/etc/sing-box/${config.name}`, oldMain);

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
    }
});
