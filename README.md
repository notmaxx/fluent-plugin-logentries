# Fluent::Plugin::Logentries
Forward logs to Logentries, using token based input.

Looks at the tag/message to find out where the log should go.

## Installation

install with gem or fluent-gem command as:

### native gem
    $ gem install fluent-plugin-logentries

### fluentd gem
    $ /opt/td-agent/embedded/bin/fluent-gem install fluent-plugin-logentries

## Configruation file (YML)

```yaml
    My-Awesome-App:
       app: MY-LOGENTRIES-TOKEN
       access: ANOTHER-LOGENTRIES-TOKEN (*)
       error: ANOTHER-LOGENTRIES-TOKEN-1 (*)
    Foo:
       app: 2bfbea1e-10c3-4419-bdad-7e6435882e1f
       access: 5deab21c-04b1-9122-abdc-09adb2eda22 (*)
       error: 9acfbeba-c92c-1229-ccac-12c58d82ecc (*)
```
(*) `access` and `error are optional, if you don't use multiple log per host just provide an app token.

This file is read everytime the buffer is flushed, it allows on fly modifications.
## Usage

```
    <match pattern>
      type logentries
      config_path /path/to/logentries-tokens.conf
    </match>
```

## Parameters

### type (required)
The value must be `logentries`.

### config_path (required)
Path of your configuration file, e.g. `/opt/logentries/tokens.conf`

### protocol
The default is `tcp`.

### use_ssl
Enable/disable SSL for data transfers between Fluentd and Logentries. The default is `true`.

### port
Only in case you don't use SSL, the value must be `80`, `514`, or `10000`. The default is `20000` (SSL)

### max_retries
Number of retries on failure.

### tag_access_log, tag_error_log
This is use in case you tag your access/error log and want them to be push into another log.

## Contributing

1. Fork it ( http://github.com/woorank/fluent-plugin-logentries/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## MIT
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
