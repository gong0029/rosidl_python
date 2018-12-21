# generated from rosidl_generator_py/resource/_msg.py.em
# generated code does not contain a copyright notice

@#######################################################################
@# EmPy template for generating _<msg>.py files
@#
@# Context:
@#  - module_name
@#  - package_name
@#  - spec (rosidl_parser.MessageSpecification)
@#    Parsed specification of the .msg file
@#  - constant_value_to_py (function)
@#  - get_python_type (function)
@#  - value_to_py (function)
@#######################################################################
@
import logging
import traceback

@{  
for field in spec.fields:
    if not field.type.is_primitive_type() and (not field.type.is_array or
          (field.type.array_size and not field.type.is_upper_bound)):

        print('from ',end='')
        print(field.type.pkg_name, end='')
        print('.msg.', end='')
        
        for s in field.type.type:
            if s.isalpha() and not s.islower():
                print('_',end='')
                print(s.lower(),end='')
            else:
                print(s,end='')
                
        print(' import ',end='')
        print(field.type.type)

}@


class Metaclass(type):
    """Metaclass of message '@(spec.base_type.type)'."""

    _CREATE_ROS_MESSAGE = None
    _CONVERT_FROM_PY = None
    _CONVERT_TO_PY = None
    _DESTROY_ROS_MESSAGE = None
    _TYPE_SUPPORT = None
    
    __constants = {
@[for constant in spec.constants]@
        '@(constant.name)': @constant_value_to_py(constant.type, constant.value),
@[end for]@
    }

    @@classmethod
    def __import_type_support__(cls):
        try:
            from rosidl_generator_py import import_type_support
            module = import_type_support('@(package_name)')
        except ImportError:
            logger = logging.getLogger('rosidl_generator_py.@(spec.base_type.type)')
            logger.debug(
                'Failed to import needed modules for type support:\n' + traceback.format_exc())
        else:
            cls._CREATE_ROS_MESSAGE = module.create_ros_message_msg_@(module_name)
            cls._CONVERT_FROM_PY = module.convert_from_py_msg_@(module_name)
            cls._CONVERT_TO_PY = module.convert_to_py_msg_@(module_name)
            cls._TYPE_SUPPORT = module.type_support_msg_@(module_name)
            cls._DESTROY_ROS_MESSAGE = module.destroy_ros_message_msg_@(module_name)
@{
importable_typesupports = {}
for field in spec.fields:
    if not field.type.is_primitive_type():
        key = '%s.msg.%s' % (field.type.pkg_name, field.type.type)
        if key not in importable_typesupports:
            importable_typesupports[key] = [field.type.pkg_name, field.type.type]
for key in sorted(importable_typesupports.keys()):
    (pkg_name, field_name) = importable_typesupports[key]
    print('%sfrom %s.msg import %s' % (' ' * 4 * 3, pkg_name, field_name))
    print('%sif %s.__class__._TYPE_SUPPORT is None:' % (' ' * 4 * 3, field_name))
    print('%s%s.__class__.__import_type_support__()' % (' ' * 4 * 4, field_name))
}@

    @@classmethod
    def __prepare__(cls, name, bases, **kwargs):
        # list constant names here so that they appear in the help text of
        # the message class under "Data and other attributes defined here:"
        # as well as populate each message instance
        return {
@[for constant in spec.constants]@
            '@(constant.name)': cls.__constants['@(constant.name)'],
@[end for]@
@[for field in spec.fields]@
@[  if field.default_value]@
            '@(field.name.upper())__DEFAULT': @value_to_py(field.type, field.default_value),
@[  end if]@
@[end for]@
        }
@[for constant in spec.constants]@

    @@property
    def @(constant.name)(self):
        """Message constant '@(constant.name)'."""
        return Metaclass.__constants['@(constant.name)']
@[end for]@
@[for field in spec.fields]@
@[  if field.default_value]@

    @@property
    def @(field.name.upper())__DEFAULT(cls):
        """Return default value for message field '@(field.name)'."""
        return @value_to_py(field.type, field.default_value)
@[  end if]@
@[end for]@


class @(spec.base_type.type)(metaclass=Metaclass):
@[if not spec.constants]@
    """Message class '@(spec.base_type.type)'."""
@[else]@
    """
    Message class '@(spec.base_type.type)'.

    Constants:
@[  for constant in spec.constants]@
      @(constant.name)
@[  end for]@
    """
@[end if]@

    __slots__ = [
@[for field in spec.fields]@
        '@(field.name)',
@[end for]@
    ]

@# wl add
    _slot_types = [
@{
print(' ' * 4 * 2,end='')
for field in spec.fields:
    if not field.type.is_primitive_type():
        if field.type.is_array:
            print('\'%s/%s[]\',' % (field.type.pkg_name, field.type.type),end='')
        else:
            print('\'%s/%s\',' % (field.type.pkg_name, field.type.type),end='')
    else:
        print('\'%s\',' % (field.type.type),end='')
}@
    ]
@# wl add end

@
@[if len(spec.fields) > 0]@

    def __init__(self, **kwargs):
    
        if kwargs:
@[  for field in spec.fields]@
@[    if field.default_value]@
            self.@(field.name) = kwargs.get(
                '@(field.name)', @(spec.base_type.type).@(field.name.upper())__DEFAULT)
@[    else]@
@[      if field.type.array_size and not field.type.is_upper_bound]@
@[        if field.type.type == 'byte']@
            self.@(field.name) = kwargs.get(
                '@(field.name)',
                [bytes([0]) for x in range(@(field.type.array_size))]
            )
@[        elif field.type.type == 'char']@
            self.@(field.name) = kwargs.get(
                '@(field.name)',
                [chr(0) for x in range(@(field.type.array_size))]
            )
@[        else]@
            self.@(field.name) = kwargs.get(
                '@(field.name)',
                [@(get_python_type(field.type))() for x in range(@(field.type.array_size))]
            )
@[        end if]@
@[      elif field.type.is_array]@
            self.@(field.name) = kwargs.get('@(field.name)', [])
@[      elif field.type.type == 'byte']@
            self.@(field.name) = kwargs.get('@(field.name)', bytes([0]))
@[      elif field.type.type == 'char']@
            self.@(field.name) = kwargs.get('@(field.name)', chr(0))
@[      else]@
            self.@(field.name) = kwargs.get('@(field.name)', @(get_python_type(field.type))())
@[      end if]@
@[    end if]@
@[  end for]@
        else:
@[  for field in spec.fields]@
@[    if field.default_value]@
            self.@(field.name) = @(spec.base_type.type).@(field.name.upper())__DEFAULT
@[    else]@
@[      if field.type.array_size and not field.type.is_upper_bound]@
@[        if field.type.type == 'byte']@
            self.@(field.name) = [bytes([0]) for x in range(@(field.type.array_size))]

@[        elif field.type.type == 'char']@
            self.@(field.name) = [chr(0) for x in range(@(field.type.array_size))]
@[        else]@
            self.@(field.name) = [@(get_python_type(field.type))() for x in range(@(field.type.array_size))]
@[        end if]@
@[      elif field.type.is_array]@
            self.@(field.name) = []
@[      elif field.type.type == 'byte']@
            self.@(field.name) = bytes([0])
@[      elif field.type.type == 'char']@
            self.@(field.name) =  chr(0)
@[      elif field.type.type == 'bool']@
            self.@(field.name) =  False
@[      elif field.type.type == 'string']@
            self.@(field.name) =  ''
@[      elif field.type.type in [
        'float32', 'float64',
        'int8', 'uint8',
        'int16', 'uint16',
        'int32', 'uint32',
        'int64', 'uint64',
    ]]@
            self.@(field.name) =  0
@[      else]@
            self.@(field.name) = @(get_python_type(field.type))()
@[      end if]@
@[    end if]@
@[  end for]@
@[end if]@

    def __repr__(self):
        typename = self.__class__.__module__.split('.')
        typename.pop()
        typename.append(self.__class__.__name__)
        args = [s[1:] + '=' + repr(getattr(self, s, None)) for s in self.__slots__]
        return '%s(%s)' % ('.'.join(typename), ', '.join(args))

    def __eq__(self, other):
        if not isinstance(other, self.__class__):
            return False
@[for field in spec.fields]@
        if self.@(field.name) != other.@(field.name):
            return False
@[end for]@
        return True
        
