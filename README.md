# Fluent::Plugin::Logentries
Forward logs to Logentries.

Looks at the tag/message to find out where the log should go.

## Installation

install with gem or fluent-gem command as:

### native gem
    $ gem install fluent-plugin-logentries-simple-config

### fluentd gem
    $ /opt/td-agent/embedded/bin/fluent-gem install fluent-plugin-logentries-simple-config

## Usage

```
    <match pattern>
      @type logentries-simple-config
      token ACBD-....
    </match>
```

## Parameters

### type (required)
The value must be `logentries-simple-config`.

### token (required)
Logentries token.

### protocol
The default is `tcp`.

### use_ssl
Enable/disable SSL for data transfers between Fluentd and Logentries. The default is `true`.

### port
Only in case you don't use SSL, the value must be `80`, `514`, or `10000`. The default is `20000` (SSL)

### max_retries
Number of retries on failure.

## Contributing

1. Fork it ( http://github.com/notmaxx/fluent-plugin-logentries/fork )
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
