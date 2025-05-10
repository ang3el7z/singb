'use strict';
'require view';
'require form';
'require ui';
'require fs';

return view.extend({
    handleSave: null,
    handleSaveApply: null,
    handleReset: null,

    async render() {
        const m = new form.Map('singb', 'Singb Configuration');
        const s = m.section(form.TypedSection, 'main', 'Control Panel');
        s.anonymous = true;

        s.tab('service', 'Service Management');
        s.tab('config', 'Edit Config');

        const getStatus = async () => {
            try {
                const result = await fs.exec('/etc/init.d/sing-box', ['status']);
                return result.stdout.trim().toLowerCase();
            } catch {
                return 'error';
            }
        };

        const notify = (type, msg) => ui.addNotification(null, msg, type);

        const getInputValueByKey = (key) => {
            const fullId = `widget.cbid.singb.main.${key}`;
            return document.querySelector(`#${CSS.escape(fullId)}`);
        };

        const loadFile = async (path) => {
            try {
                return await fs.read(path) || '';
            } catch {
                return '';
            }
        };

        const saveFile = async (path, value, message = 'Saved!') => {
            try {
                await fs.write(path, value);
                notify('info', message);
            } catch (e) {
                notify('error', 'Error: ' + e.message);
            }
        };

        const status = await getStatus();

        const statusDisplay = s.taboption('service', form.DummyValue, 'service_status', 'Service Status');
        statusDisplay.rawhtml = true;
        statusDisplay.cfgvalue = () => {
            if (status === 'running') return '<span style="color: green; font-weight: bold;">Running</span>';
            if (status === 'inactive') return '<span style="color: red; font-weight: bold;">Inactive</span>';
            if (status === 'error') return '<span style="color: red;">Error fetching status</span>';
            return `<span style="color: orange;">${status}</span>`;
        };

        const actions = ['start', 'stop', 'restart', 'reload'];
        actions.forEach(action => {
            const shouldShow =
                (action === 'start' && status !== 'running') ||
                (['stop', 'restart', 'reload'].includes(action) && status === 'running');

            if (!shouldShow) return;

            const btn = s.taboption('service', form.Button, action, action.charAt(0).toUpperCase() + action.slice(1));
            btn.inputstyle = action === 'stop' ? 'remove' : 'apply';
            btn.onclick = async () => {
                try {
                    await fs.exec('/etc/init.d/sing-box', [action]);
                    notify('info', `${action} successful`);
                    setTimeout(() => location.reload(), 1000);
                } catch (e) {
                    notify('error', `${action} failed: ${e.message}`);
                }
            };
        });

        const configs = [
            { name: 'config.json', label: 'Main Config' },
            { name: 'config2.json', label: 'Backup Config #1' },
            { name: 'config3.json', label: 'Backup Config #2' }
        ];

        for (const config of configs) {
            const tabName = config.name === 'config.json' ? 'main_config' : `config_${config.name}`;
            s.tab(tabName, config.label);

            const urlKey = `subscribe_url_${config.name}`;
            const urlInput = s.taboption(tabName, form.Value, urlKey, 'Subscribe URL');
            urlInput.datatype = 'url';
            urlInput.placeholder = 'https://example.com/subscribe';
            urlInput.rmempty = false;
            urlInput.load = () => loadFile(`/etc/sing-box/url_${config.name}`);

            const saveUrlBtn = s.taboption(tabName, form.Button, `save_url_${config.name}`, 'Save URL');
            saveUrlBtn.inputstyle = 'apply';
            saveUrlBtn.onclick = async () => {
                const el = getInputValueByKey(urlKey);
                if (!el || !el.value.trim()) return notify('error', 'Empty URL field');
                await saveFile(`/etc/sing-box/url_${config.name}`, el.value.trim(), 'URL saved');
            };

            const updateBtn = s.taboption(tabName, form.Button, `update_${config.name}`, 'Update Config');
            updateBtn.inputstyle = 'reload';
            updateBtn.onclick = async () => {
                try {
                    const url = (await loadFile(`/etc/sing-box/url_${config.name}`)).trim();
                    if (!url) throw new Error('URL is empty');
                    const result = await fs.exec('/usr/bin/singb-updater', [`/etc/sing-box/url_${config.name}`, `/etc/sing-box/${config.name}`]);
                    if (result.code !== 0) throw new Error(result.stderr || result.stdout || 'Unknown error');
                    if (config.name === 'config.json') {
                        await fs.exec('/etc/init.d/sing-box', ['reload']);
                        notify('info', 'Config reloaded');
                        setTimeout(() => location.reload(), 1000);
                    }
                } catch (e) {
                    notify('error', 'Update failed: ' + e.message);
                }
            };

            const contentKey = `content_${config.name}`;
            const textValue = s.taboption(tabName, form.TextValue, contentKey, config.label);
            textValue.rows = 25;
            textValue.wrap = 'off';
            textValue.cfgvalue = () => loadFile(`/etc/sing-box/${config.name}`);

            const saveContentBtn = s.taboption(tabName, form.Button, `save_content_${config.name}`, 'Save Config');
            saveContentBtn.inputstyle = 'apply';
            saveContentBtn.onclick = async () => {
                const el = getInputValueByKey(contentKey);
                if (!el || !el.value.trim()) return notify('error', 'Config is empty');
                await saveFile(`/etc/sing-box/${config.name}`, el.value.trim(), 'Config saved');
                if (config.name === 'config.json') {
                    await fs.exec('/etc/init.d/sing-box', ['reload']);
                    notify('info', 'Config reloaded');
                    setTimeout(() => location.reload(), 1000);
                }
            };

            if (config.name !== 'config.json') {
                const setMainBtn = s.taboption(tabName, form.Button, `set_main_${config.name}`, 'Set as Main');
                setMainBtn.inputstyle = 'apply';
                setMainBtn.onclick = async () => {
                    try {
                        const newMainContent = await loadFile(`/etc/sing-box/${config.name}`);
                        const oldMainContent = await loadFile('/etc/sing-box/config.json');
                        const newMainUrl = await loadFile(`/etc/sing-box/url_${config.name}`);
                        const oldMainUrl = await loadFile('/etc/sing-box/url_config.json');

                        await saveFile('/etc/sing-box/config.json', newMainContent);
                        await saveFile(`/etc/sing-box/${config.name}`, oldMainContent);
                        await saveFile('/etc/sing-box/url_config.json', newMainUrl);
                        await saveFile(`/etc/sing-box/url_${config.name}`, oldMainUrl);

                        await fs.exec('/etc/init.d/sing-box', ['reload']);
                        notify('info', `${config.label} is now main`);
                        setTimeout(() => location.reload(), 1000);
                    } catch (e) {
                        notify('error', `Failed to set ${config.label} as main: ${e.message}`);
                    }
                };
            }
        }

        return m.render();
    }
});
