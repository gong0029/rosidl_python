# Copyright 2014-2016 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from collections import defaultdict
import os

from rosidl_cmake import convert_camel_case_to_lower_case_underscore
from rosidl_cmake import expand_template
from rosidl_cmake import get_newest_modification_time
from rosidl_cmake import read_generator_arguments
from rosidl_generator_c import primitive_msg_type_to_c
from rosidl_parser import parse_message_file
from rosidl_parser import parse_service_file

from .generate_proto import get_protos_dir,get_package_name,msg2proto,cp_gen_py_to_proto,proto_gen_py

def generate_py(generator_arguments_file, typesupport_impls):

    protos_dir = get_protos_dir()
    print(protos_dir)

    args = read_generator_arguments(generator_arguments_file)

    template_dir = args['template_dir']
    type_support_impl_by_filename = {
        '_%s_s.ep.{0}.c'.format(impl): impl for impl in typesupport_impls
    }
    mapping_msgs = {
        os.path.join(template_dir, '_msg.py.em'): ['_%s.py'],
        os.path.join(template_dir, '_msg_support.c.em'): ['_%s_s.c'],
    }
    mapping_msg_pkg_extension = {
        os.path.join(template_dir, '_msg_pkg_typesupport_entry_point.c.em'):
        type_support_impl_by_filename.keys(),
    }

    mapping_srvs = {
        os.path.join(template_dir, '_srv.py.em'): ['_%s.py'],
    }

    for template_file in mapping_msgs.keys():
        assert os.path.exists(template_file), 'Could not find template: ' + template_file
    for template_file in mapping_msg_pkg_extension.keys():
        assert os.path.exists(template_file), 'Could not find template: ' + template_file
    for template_file in mapping_srvs.keys():
        assert os.path.exists(template_file), 'Could not find template: ' + template_file

    functions = {
        'constant_value_to_py': constant_value_to_py,
        'get_python_type': get_python_type,
        'primitive_msg_type_to_c': primitive_msg_type_to_c,
        'value_to_py': value_to_py,
        'convert_camel_case_to_lower_case_underscore': convert_camel_case_to_lower_case_underscore,
    }
    latest_target_timestamp = get_newest_modification_time(args['target_dependencies'])

    modules = defaultdict(list)
    message_specs = []
    service_specs = []
    for ros_interface_file in args['ros_interface_files']:
        extension = os.path.splitext(ros_interface_file)[1]
        subfolder = os.path.basename(os.path.dirname(ros_interface_file))
        if extension == '.msg':
            spec = parse_message_file(args['package_name'], ros_interface_file)
            message_specs.append((spec, subfolder))
            mapping = mapping_msgs
            type_name = spec.base_type.type
        elif extension == '.srv':
            spec = parse_service_file(args['package_name'], ros_interface_file)
            service_specs.append((spec, subfolder))
            mapping = mapping_srvs
            type_name = spec.srv_name
        else:
            continue

        if extension == '.msg':
            print(ros_interface_file)
            module_name, filename = get_package_name(ros_interface_file)
            spec = parse_message_file(module_name, ros_interface_file)
            msg2proto(spec, protos_dir, args['package_name'], filename)

        module_name = convert_camel_case_to_lower_case_underscore(type_name)
        modules[subfolder].append((module_name, type_name))
        for template_file, generated_filenames in mapping.items():
            for generated_filename in generated_filenames:
                data = {
                    'module_name': module_name,
                    'package_name': args['package_name'],
                    'spec': spec, 'subfolder': subfolder,
                }
                data.update(functions)
                generated_file = os.path.join(
                    args['output_dir'], subfolder, generated_filename % module_name)
                expand_template(
                    template_file, data, generated_file,
                    minimum_timestamp=latest_target_timestamp)


    for subfolder in modules.keys():
        import_list = {}
        for module_name, type_ in modules[subfolder]:
            if subfolder == 'srv' and (type_.endswith('Request') or type_.endswith('Response')):
                continue
            import_list['%s  # noqa\n' % type_] = 'from %s.%s._%s import %s\n' % \
                (args['package_name'], subfolder, module_name, type_)

        with open(os.path.join(args['output_dir'], subfolder, '__init__.py'), 'w') as f:
            for import_line in sorted(import_list.values()):
                f.write(import_line)
            for noqa_line in sorted(import_list.keys()):
                        f.write(noqa_line)

        if subfolder == 'msg':
            proto_moudle_name = os.path.basename(args['output_dir'])

            proto_gen_py(proto_moudle_name)
            cp_gen_py_to_proto(args['output_dir'],proto_moudle_name)

            with open(os.path.join(args['output_dir'], 'proto', '__init__.py'), 'w') as f:
                f.write('def set_proto_constants(msg_cls, proto_cls):\n')
                f.write(' '*4+'for k,v in msg_cls.__class__._Metaclass__constants.items():\n')
                f.write(' '*8+'if hasattr(proto_cls,k):\n')
                f.write(' '*12+'raise Exception("%s has key: %s" % (str(msg_cls), k))\n')
                f.write(' '*8+'else:\n')
                f.write(' '*12+'setattr(proto_cls,k,v)\n')
                f.write('\n')

                for import_line in sorted(import_list.values()):
                    clazz = import_line[import_line.find(' import ')+8:].strip()
                    import_line = import_line.strip()+ " as "+clazz+"_msg"
                    f.write(import_line+'\n')

                f.write('\n')

                for import_line in sorted(import_list.values()):
                    clazz = import_line[import_line.find(' import ') + 8:].strip()
                    import_line = import_line[:import_line.index('.')]
                    import_line += ".proto."+clazz+"_pb2 import "+clazz

                    f.write(import_line+'\n')

                f.write('\n')

                for import_line in sorted(import_list.values()):
                    clazz = import_line[import_line.find(' import ') + 8:].strip()

                    f.write(clazz+".__import_type_support__ = "+clazz+
                            "_msg.__class__.__import_type_support__\n")
                    f.write(clazz + ".__import_type_support__()\n")
                    f.write(clazz +"._TYPE_SUPPORT = "+clazz+"_msg.__class__._TYPE_SUPPORT\n")
                    f.write(clazz + "._use_proto_=True\n")
                f.write('\n')

                for import_line in sorted(import_list.values()):
                    msg_clazz = import_line[import_line.find(' import ') + 8:].strip()
                    proto_clazz = msg_clazz
                    msg_clazz = msg_clazz+"_msg"
                    f.write('set_proto_constants(%s,%s)\n' % (msg_clazz,proto_clazz))
                f.write('\n')


    for template_file, generated_filenames in mapping_msg_pkg_extension.items():
        for generated_filename in generated_filenames:
            data = {
                'package_name': args['package_name'],
                'message_specs': message_specs,
                'service_specs': service_specs,
                'typesupport_impl': type_support_impl_by_filename.get(generated_filename, ''),
            }
            data.update(functions)
            generated_file = os.path.join(
                args['output_dir'], generated_filename % args['package_name'])
            expand_template(
                template_file, data, generated_file,
                minimum_timestamp=latest_target_timestamp)

    return 0


def value_to_py(type_, value, array_as_tuple=False):
    assert type_.is_primitive_type()
    assert value is not None

    if not type_.is_array:
        return primitive_value_to_py(type_, value)

    py_values = []
    for single_value in value:
        py_value = primitive_value_to_py(type_, single_value)
        py_values.append(py_value)
    if array_as_tuple:
        return '(%s)' % ', '.join(py_values)
    else:
        return '[%s]' % ', '.join(py_values)


def primitive_value_to_py(type_, value):
    assert type_.is_primitive_type()
    assert value is not None

    if type_.type == 'bool':
        return 'True' if value else 'False'

    if type_.type in [
        'int8', 'uint8',
        'int16', 'uint16',
        'int32', 'uint32',
        'int64', 'uint64',
    ]:
        return str(value)

    if type_.type == 'char':
        return repr('%c' % value)

    if type_.type == 'byte':
        return repr(bytes([value]))

    if type_.type in ['float32', 'float64']:
        return '%s' % value

    if type_.type == 'string':
        return "'%s'" % escape_string(value)

    assert False, "unknown primitive type '%s'" % type_.type


def constant_value_to_py(type_, value):
    assert value is not None

    if type_ == 'bool':
        return 'True' if value else 'False'

    if type_ in [
        'int8', 'uint8',
        'int16', 'uint16',
        'int32', 'uint32',
        'int64', 'uint64',
    ]:
        return str(value)

    if type_ == 'char':
        return repr('%c' % value)

    if type_ == 'byte':
        return repr(bytes([value]))

    if type_ in ['float32', 'float64']:
        return '%s' % value

    if type_ == 'string':
        return "'%s'" % escape_string(value)

    assert False, "unknown constant type '%s'" % type_


def escape_string(s):
    s = s.replace('\\', '\\\\')
    s = s.replace("'", "\\'")
    return s


def get_python_type(type_):
    if not type_.is_primitive_type():
        return type_.type

    if type_.string_upper_bound:
        return 'str'

    if type_.is_array:
        if type_.type == 'byte':
            return 'bytes'

        if type_.type == 'char':
            return 'str'

    if type_.type == 'bool':
        return 'bool'

    if type_.type == 'byte':
        return 'bytes'

    if type_.type in [
        'int8', 'uint8',
        'int16', 'uint16',
        'int32', 'uint32',
        'int64', 'uint64',
    ]:
        return 'int'

    if type_.type in ['float32', 'float64']:
        return 'float'

    if type_.type in ['char', 'string']:
        return 'str'

    assert False, "unknown type '%s'" % type_
