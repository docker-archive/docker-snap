import os

import snapcraft

class ShellPlugin(snapcraft.BasePlugin):
	@classmethod
	def schema(cls):
		schema = super().schema()

		schema['required'] = []

		schema['properties']['shell'] = {
			'type': 'string',
			'default': '/bin/sh',
		}
		schema['required'].append('shell')

		schema['properties']['shell-flags'] = {
			'type': 'array',
			'items': {
				'type': 'string',
			},
			'default': [],
		}

		schema['properties']['shell-command'] = {
			'type': 'string',
		}
		schema['required'].append('shell-command')

		return schema

	def env(self, root):
		# ensure we pass forward any "proxy" related environment variables
		proxy_vars = [ (key + '=' + val) for key, val in os.environ.items() if "proxy" in key or "PROXY" in key ]

		return super().env(root) + proxy_vars + [
			'DESTDIR=' + self.installdir,
			'SNAPDIR=' + os.getcwd(),
		]

	def build(self):
		super().build()

		return self.run([
			self.options.shell,
		] + self.options.shell_flags + [
			'-c', self.options.shell_command,
		])

# vim:set ts=4 noet:
